use std::{
    cell::RefCell,
    env,
    fs,
    path::{Path, PathBuf},
    rc::Rc,
    time::{Duration, Instant},
};

use cairo::{
    Context, Filter, FontSlant, FontWeight, Format, ImageSurface, Operator,
};
use gtk::{
    gdk, gio, glib,
    prelude::*,
    Application, ApplicationWindow, DrawingArea,
};
use image::{imageops::FilterType, GenericImageView};

const APP_ID: &str = "io.github.tqqniri.WallpaperGallery";
const WINDOW_TITLE: &str = "TQQ Wallpaper Gallery";
const ANIMATION_TIME: Duration = Duration::from_millis(280);
const IMAGE_EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "webp"];

#[derive(Clone, Copy)]
struct Color(f64, f64, f64);

const TEXT: Color = Color(0.97, 0.95, 1.0);
const MUTED: Color = Color(0.84, 0.81, 0.91);
const ACCENT: Color = Color(0.78, 0.55, 0.96);

struct Wallpaper {
    path: PathBuf,
    surface: ImageSurface,
    width: f64,
    height: f64,
    palette: [Color; 5],
}

#[derive(Clone, Copy)]
struct HitBox {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    index: usize,
    selected: bool,
}

struct Model {
    wallpapers: Vec<Wallpaper>,
    position: f64,
    target: f64,
    animation_from: f64,
    animation_started: Instant,
    animation_generation: u64,
    hit_boxes: Vec<HitBox>,
    selected: Option<PathBuf>,
}

fn collect_images(directory: &Path, output: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(directory)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_dir() {
            collect_images(&path, output)?;
        } else if path.is_file() {
            let extension = path
                .extension()
                .and_then(|value| value.to_str())
                .unwrap_or("")
                .to_ascii_lowercase();
            if IMAGE_EXTENSIONS.contains(&extension.as_str()) {
                output.push(path);
            }
        }
    }
    Ok(())
}

fn image_surface(path: &Path) -> Result<(ImageSurface, f64, f64, [Color; 5]), String> {
    let decoded = image::open(path)
        .map_err(|error| format!("Cannot decode {}: {error}", path.display()))?;
    let resized = decoded.resize(900, 620, FilterType::Triangle).to_rgba8();
    let (width, height) = resized.dimensions();
    let mut cairo_data = vec![0_u8; (width * height * 4) as usize];

    // Cairo ARgb32 is premultiplied and stored as BGRA on little-endian systems.
    for (source, target) in resized
        .as_raw()
        .chunks_exact(4)
        .zip(cairo_data.chunks_exact_mut(4))
    {
        let alpha = source[3] as u16;
        target[0] = ((source[2] as u16 * alpha + 127) / 255) as u8;
        target[1] = ((source[1] as u16 * alpha + 127) / 255) as u8;
        target[2] = ((source[0] as u16 * alpha + 127) / 255) as u8;
        target[3] = source[3];
    }

    let stride = width as i32 * 4;
    let surface = ImageSurface::create_for_data(
        cairo_data,
        Format::ARgb32,
        width as i32,
        height as i32,
        stride,
    )
    .map_err(|error| format!("Cannot create image surface: {error}"))?;

    let mut palette = [ACCENT; 5];
    let fractions = [0.12, 0.30, 0.50, 0.70, 0.88];
    for (slot, fraction) in palette.iter_mut().zip(fractions) {
        let x = ((width as f64 * fraction) as u32).min(width.saturating_sub(1));
        let y = ((height as f64 * 0.48) as u32).min(height.saturating_sub(1));
        let pixel = resized.get_pixel(x, y);
        *slot = Color(
            (0.18 + pixel[0] as f64 / 255.0 * 0.82).min(1.0),
            (0.18 + pixel[1] as f64 / 255.0 * 0.82).min(1.0),
            (0.18 + pixel[2] as f64 / 255.0 * 0.82).min(1.0),
        );
    }

    Ok((surface, width as f64, height as f64, palette))
}

fn load_wallpapers(paths: &[PathBuf]) -> Result<Vec<Wallpaper>, String> {
    let mut wallpapers = Vec::with_capacity(paths.len());
    for path in paths {
        let (surface, width, height, palette) = image_surface(path)?;
        wallpapers.push(Wallpaper {
            path: path.clone(),
            surface,
            width,
            height,
            palette,
        });
    }
    Ok(wallpapers)
}

fn rounded_rectangle(cr: &Context, x: f64, y: f64, width: f64, height: f64, radius: f64) {
    let radius = radius.min(width / 2.0).min(height / 2.0);
    cr.new_sub_path();
    cr.arc(
        x + width - radius,
        y + radius,
        radius,
        -std::f64::consts::FRAC_PI_2,
        0.0,
    );
    cr.arc(
        x + width - radius,
        y + height - radius,
        radius,
        0.0,
        std::f64::consts::FRAC_PI_2,
    );
    cr.arc(
        x + radius,
        y + height - radius,
        radius,
        std::f64::consts::FRAC_PI_2,
        std::f64::consts::PI,
    );
    cr.arc(
        x + radius,
        y + radius,
        radius,
        std::f64::consts::PI,
        std::f64::consts::PI * 1.5,
    );
    cr.close_path();
}

fn source_color(cr: &Context, color: Color, alpha: f64) {
    cr.set_source_rgba(color.0, color.1, color.2, alpha);
}

fn draw_text(
    cr: &Context,
    text: &str,
    x: f64,
    y: f64,
    size: f64,
    color: Color,
    bold: bool,
    centered: bool,
    canvas_width: f64,
) {
    cr.select_font_face(
        "JetBrainsMono Nerd Font",
        FontSlant::Normal,
        if bold { FontWeight::Bold } else { FontWeight::Normal },
    );
    cr.set_font_size(size);
    let extents = match cr.text_extents(text) {
        Ok(value) => value,
        Err(_) => return,
    };
    let draw_x = if centered {
        (canvas_width - extents.width()) / 2.0 - extents.x_bearing()
    } else {
        x
    };

    cr.save().ok();
    cr.move_to(draw_x + 1.0, y + 2.0);
    cr.set_source_rgba(0.0, 0.0, 0.0, 0.62);
    cr.show_text(text).ok();
    cr.restore().ok();

    cr.move_to(draw_x, y);
    source_color(cr, color, 1.0);
    cr.show_text(text).ok();
}

fn draw_card(
    cr: &Context,
    wallpaper: &Wallpaper,
    center_x: f64,
    center_y: f64,
    card_width: f64,
    card_height: f64,
    angle: f64,
    alpha: f64,
    focused: bool,
) {
    cr.save().ok();
    cr.translate(center_x, center_y);
    cr.rotate(angle);

    let x = -card_width / 2.0;
    let y = -card_height / 2.0;

    // Soft drop shadow; the top-level window itself stays fully transparent.
    rounded_rectangle(cr, x - 4.0, y + 12.0, card_width + 8.0, card_height + 9.0, 19.0);
    cr.set_source_rgba(0.0, 0.0, 0.0, 0.46 * alpha);
    cr.fill().ok();

    rounded_rectangle(cr, x - 1.4, y - 1.4, card_width + 2.8, card_height + 2.8, 19.0);
    source_color(cr, ACCENT, if focused { 0.92 * alpha } else { 0.25 * alpha });
    cr.fill().ok();

    rounded_rectangle(cr, x, y, card_width, card_height, 18.0);
    cr.clip();
    cr.scale(card_width / wallpaper.width, card_height / wallpaper.height);
    cr.set_source_surface(&wallpaper.surface, -wallpaper.width / 2.0, -wallpaper.height / 2.0)
        .ok();
    if let Some(pattern) = cr.source() {
        pattern.set_filter(Filter::Bilinear);
    }
    cr.paint_with_alpha(alpha).ok();
    cr.restore().ok();
}

fn draw_gallery(model: &mut Model, cr: &Context, width: i32, height: i32) {
    let width = width as f64;
    let height = height as f64;
    if model.wallpapers.is_empty() {
        return;
    }

    // Do not paint a panel or a solid window background.
    cr.save().ok();
    cr.set_operator(Operator::Clear);
    cr.paint().ok();
    cr.set_operator(Operator::Over);
    cr.restore().ok();

    let count = model.wallpapers.len() as isize;
    let nearest = model.position.round() as isize;
    let center_x = width * 0.5;
    let center_y = height * 0.46;
    let base_width = 590.0_f64.min(width * 0.49);
    let base_height = 390.0_f64.min(height * 0.52);
    let spacing = 218.0_f64.min(width * 0.195);
    model.hit_boxes.clear();

    for offset in (-3_isize..=3).rev() {
        let virtual_index = nearest + offset;
        let index = virtual_index.rem_euclid(count) as usize;
        let delta = virtual_index as f64 - model.position;
        let distance = delta.abs();
        let focus = (1.0 - distance).max(0.0);
        let scale = 0.76 + 0.24 * focus;
        let card_width = base_width * scale;
        let card_height = base_height * (0.82 + 0.18 * focus);
        let x = center_x + delta * spacing;
        let angle = (delta * 0.23).clamp(-0.34, 0.34);
        let alpha = 0.54 + 0.46 * focus;
        let selected = distance < 0.5;

        draw_card(
            cr,
            &model.wallpapers[index],
            x,
            center_y,
            card_width,
            card_height,
            angle,
            alpha,
            selected,
        );

        if distance <= 1.15 {
            model.hit_boxes.push(HitBox {
                x: x - card_width / 2.0,
                y: center_y - card_height / 2.0,
                width: card_width,
                height: card_height,
                index,
                selected,
            });
        }
    }

    let selected_index = (model.position.round() as isize).rem_euclid(count) as usize;
    let wallpaper = &model.wallpapers[selected_index];
    let label = wallpaper
        .path
        .file_stem()
        .and_then(|value| value.to_str())
        .unwrap_or("Wallpaper")
        .replace(['_', '-'], " ");

    draw_text(
        cr,
        &label,
        0.0,
        height * 0.79,
        19.0,
        TEXT,
        true,
        true,
        width,
    );
    draw_text(
        cr,
        wallpaper.path.file_name().and_then(|v| v.to_str()).unwrap_or(""),
        0.0,
        height * 0.79 + 28.0,
        10.0,
        MUTED,
        false,
        true,
        width,
    );

    let swatch_size = 17.0;
    let gap = 11.0;
    let total = 5.0 * swatch_size + 4.0 * gap;
    let start = (width - total) / 2.0;
    for (position, color) in wallpaper.palette.iter().enumerate() {
        let x = start + position as f64 * (swatch_size + gap);
        rounded_rectangle(cr, x, height * 0.87, swatch_size, swatch_size, 5.0);
        source_color(cr, *color, 0.96);
        cr.fill().ok();
    }

    draw_text(
        cr,
        "← / →  browse     scroll  browse     enter  apply     esc  close",
        0.0,
        height - 30.0,
        10.0,
        MUTED,
        false,
        true,
        width,
    );
}

fn animate_to(model: &Rc<RefCell<Model>>, area: &DrawingArea, destination: f64) {
    let generation = {
        let mut state = model.borrow_mut();
        state.animation_from = state.position;
        state.target = destination;
        state.animation_started = Instant::now();
        state.animation_generation = state.animation_generation.wrapping_add(1);
        state.animation_generation
    };

    let model = Rc::clone(model);
    let area = area.clone();
    glib::timeout_add_local(Duration::from_millis(16), move || {
        let mut state = model.borrow_mut();
        if state.animation_generation != generation {
            return glib::ControlFlow::Break;
        }

        let elapsed = state.animation_started.elapsed().as_secs_f64();
        let progress = (elapsed / ANIMATION_TIME.as_secs_f64()).clamp(0.0, 1.0);
        let eased = 1.0 - (1.0 - progress).powi(3);
        state.position =
            state.animation_from + (state.target - state.animation_from) * eased;

        if progress >= 1.0 {
            state.position = state.target;
            area.queue_draw();
            glib::ControlFlow::Break
        } else {
            area.queue_draw();
            glib::ControlFlow::Continue
        }
    });
}

fn shortest_target(current_target: f64, index: usize, count: usize) -> f64 {
    let count = count as f64;
    let current_mod = current_target.rem_euclid(count);
    let delta = (index as f64 - current_mod + count / 2.0).rem_euclid(count) - count / 2.0;
    current_target + delta
}

fn build_window(
    app: &Application,
    wallpapers: Vec<Wallpaper>,
    current: Option<PathBuf>,
    selected: Rc<RefCell<Option<PathBuf>>>,
) {
    let initial_index = current
        .as_ref()
        .and_then(|path| wallpapers.iter().position(|wallpaper| &wallpaper.path == path))
        .unwrap_or(0);

    let model = Rc::new(RefCell::new(Model {
        wallpapers,
        position: initial_index as f64,
        target: initial_index as f64,
        animation_from: initial_index as f64,
        animation_started: Instant::now(),
        animation_generation: 0,
        hit_boxes: Vec::new(),
        selected: None,
    }));

    let area = DrawingArea::new();
    area.set_content_width(1120);
    area.set_content_height(720);
    area.set_hexpand(true);
    area.set_vexpand(true);
    area.set_focusable(true);

    let draw_model = Rc::clone(&model);
    area.set_draw_func(move |_area, cr, width, height| {
        draw_gallery(&mut draw_model.borrow_mut(), cr, width, height);
    });

    let window = ApplicationWindow::builder()
        .application(app)
        .title(WINDOW_TITLE)
        .default_width(1120)
        .default_height(720)
        .decorated(false)
        .build();
    window.set_css_classes(&["tqq-transparent-wallpaper-gallery"]);
    window.set_child(Some(&area));

    let key = gtk::EventControllerKey::new();
    let key_model = Rc::clone(&model);
    let key_area = area.clone();
    let key_selected = Rc::clone(&selected);
    let key_window = window.clone();
    key.connect_key_pressed(move |_controller, keyval, _keycode, _modifier| {
        let handled = match keyval {
            gdk::Key::Left | gdk::Key::h => {
                let destination = key_model.borrow().target - 1.0;
                animate_to(&key_model, &key_area, destination);
                true
            }
            gdk::Key::Right | gdk::Key::l => {
                let destination = key_model.borrow().target + 1.0;
                animate_to(&key_model, &key_area, destination);
                true
            }
            gdk::Key::Home => {
                animate_to(&key_model, &key_area, 0.0);
                true
            }
            gdk::Key::Return | gdk::Key::KP_Enter => {
                let state = key_model.borrow();
                let index = (state.position.round() as isize)
                    .rem_euclid(state.wallpapers.len() as isize) as usize;
                *key_selected.borrow_mut() = Some(state.wallpapers[index].path.clone());
                key_window.close();
                true
            }
            gdk::Key::Escape => {
                key_window.close();
                true
            }
            _ => false,
        };

        if handled {
            glib::Propagation::Stop
        } else {
            glib::Propagation::Proceed
        }
    });
    area.add_controller(key);

    let scroll = gtk::EventControllerScroll::new(
        gtk::EventControllerScrollFlags::VERTICAL | gtk::EventControllerScrollFlags::DISCRETE,
    );
    let scroll_model = Rc::clone(&model);
    let scroll_area = area.clone();
    scroll.connect_scroll(move |_controller, _dx, dy| {
        let destination = if dy < 0.0 {
            scroll_model.borrow().target - 1.0
        } else {
            scroll_model.borrow().target + 1.0
        };
        animate_to(&scroll_model, &scroll_area, destination);
        glib::Propagation::Stop
    });
    area.add_controller(scroll);

    let click = gtk::GestureClick::new();
    click.set_button(1);
    let click_model = Rc::clone(&model);
    let click_area = area.clone();
    let click_selected = Rc::clone(&selected);
    let click_window = window.clone();
    click.connect_pressed(move |_gesture, _presses, x, y| {
        let hit = {
            let state = click_model.borrow();
            state.hit_boxes.iter().rev().find(|hit| {
                x >= hit.x
                    && x <= hit.x + hit.width
                    && y >= hit.y
                    && y <= hit.y + hit.height
            }).copied()
        };

        if let Some(hit) = hit {
            if hit.selected {
                let state = click_model.borrow();
                *click_selected.borrow_mut() = Some(state.wallpapers[hit.index].path.clone());
                click_window.close();
            } else {
                let target = {
                    let state = click_model.borrow();
                    shortest_target(state.target, hit.index, state.wallpapers.len())
                };
                animate_to(&click_model, &click_area, target);
            }
        }
    });
    area.add_controller(click);

    let css = gtk::CssProvider::new();
    css.load_from_data(
        "window.tqq-transparent-wallpaper-gallery, \
         window.tqq-transparent-wallpaper-gallery > * { \
             background: transparent; \
             background-color: transparent; \
             background-image: none; \
             border: none; \
             box-shadow: none; \
         }",
    );
    if let Some(display) = gdk::Display::default() {
        gtk::style_context_add_provider_for_display(
            &display,
            &css,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }

    window.present();
    area.grab_focus();
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!(
            "Usage: tqq-wallpaper-gallery WALLPAPER_DIR CURRENT_WALLPAPER_FILE"
        );
        std::process::exit(2);
    }

    let wallpaper_directory = PathBuf::from(&args[1]);
    let state_file = PathBuf::from(&args[2]);

    if !wallpaper_directory.is_dir() {
        eprintln!("Wallpaper directory not found: {}", wallpaper_directory.display());
        std::process::exit(1);
    }

    let mut paths = Vec::new();
    if let Err(error) = collect_images(&wallpaper_directory, &mut paths) {
        eprintln!("Cannot scan wallpaper directory: {error}");
        std::process::exit(1);
    }
    paths.sort_by_key(|path| {
        path.file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("")
            .to_ascii_lowercase()
    });

    if paths.is_empty() {
        eprintln!("No supported images found in {}", wallpaper_directory.display());
        std::process::exit(1);
    }

    let wallpapers = match load_wallpapers(&paths) {
        Ok(images) => images,
        Err(error) => {
            eprintln!("{error}");
            std::process::exit(1);
        }
    };

    let current = fs::read_to_string(&state_file)
        .ok()
        .map(|value| PathBuf::from(value.trim()));

    let app = Application::builder()
        .application_id(APP_ID)
        .flags(gio::ApplicationFlags::NON_UNIQUE)
        .build();

    let selected: Rc<RefCell<Option<PathBuf>>> = Rc::new(RefCell::new(None));
    let activate_selected = Rc::clone(&selected);
    let wallpapers_for_window = wallpapers;

    app.connect_activate(move |application| {
        build_window(
            application,
            // GTK Application activates once per process because NON_UNIQUE is set.
            wallpapers_for_window
                .iter()
                .map(|wallpaper| Wallpaper {
                    path: wallpaper.path.clone(),
                    surface: wallpaper.surface.clone(),
                    width: wallpaper.width,
                    height: wallpaper.height,
                    palette: wallpaper.palette,
                })
                .collect(),
            current.clone(),
            Rc::clone(&activate_selected),
        );
    });

    app.run();

    if let Some(path) = selected.borrow().as_ref() {
        println!("{}", path.display());
    }
}
