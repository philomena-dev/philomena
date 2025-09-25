use image::{DynamicImage, ImageBuffer, ImageReader, Pixel};
use std::io::BufReader;
use tch::{CModule, Device, Tensor};

use crate::FeatureExtractionError;

pub fn device_and_model(model_path: &str) -> Option<(Device, CModule)> {
    let device = Device::cuda_if_available();
    let model = CModule::load_on_device(model_path, device);

    match model {
        Err(err) => {
            eprintln!("failed to load model from {model_path}: {err}");
            None
        }
        Ok(model) => Some((device, model)),
    }
}

fn into_tensor<P: Pixel<Subpixel = f32>>(
    image: ImageBuffer<P, Vec<f32>>,
    device: Device,
) -> Tensor {
    let w: i64 = image.width().into();
    let h: i64 = image.height().into();
    let c: i64 = P::CHANNEL_COUNT.into();

    // Extra scope to ensure we eagerly drop the original image buffer
    let pixels = {
        let pixels: Vec<f32> = image.pixels().flat_map(|p| p.channels()).copied().collect();

        Tensor::from_slice(&pixels)
    };

    pixels.to(device).reshape([h, w, c]).permute([2, 0, 1])
}

fn strip_transparency(image: DynamicImage, device: Device) -> Tensor {
    let w: i64 = image.width().into();
    let h: i64 = image.height().into();

    match image {
        DynamicImage::ImageRgb8(..)
        | DynamicImage::ImageLuma8(..)
        | DynamicImage::ImageLuma16(..)
        | DynamicImage::ImageRgb16(..)
        | DynamicImage::ImageRgb32F(..) => {
            return into_tensor(image.into_rgb32f(), device);
        }
        _ => {}
    };

    // Get channels.
    let (alpha, color) = {
        let pixels = into_tensor(image.into_rgba32f(), device);
        let alpha = pixels.slice(0, 3, 4, 1).broadcast_to([3, h, w]);
        let color = pixels.slice(0, 0, 3, 1);

        (alpha, color)
    };

    // Detect whether premultiplication should be applied by checking
    // for channels with values above the alpha level.
    //
    // Note that the only input format which we can get where this would
    // be relevant, PNG, explicitly says it does not carry premultiplied alpha,
    // but many tools will store premultiplied alpha anyway...
    let ones = Tensor::ones([3, h, w], (tch::Kind::Float, device));
    let mask = alpha.where_self(&color.gt_tensor(&alpha).any(), &ones);
    let color = color.multiply(&mask);

    // Pure transparency is rescaled to be 8 steps blacker than black.
    const ALPHA_LEVEL: f64 = 8.0 / 255.0;
    const COLOR_LEVEL: f64 = 1.0 - ALPHA_LEVEL;

    // Unwrap is guaranteed safe because the dimensions and data type match
    color
        .multiply_scalar(COLOR_LEVEL)
        .f_add(&alpha.multiply_scalar(ALPHA_LEVEL))
        .unwrap()
}

pub fn load_image<R>(image: R, device: Device) -> Result<Tensor, FeatureExtractionError>
where
    R: std::io::Read + std::io::Seek,
{
    let image = BufReader::new(image);
    let image = ImageReader::new(image)
        .with_guessed_format()
        .map_err(|_| FeatureExtractionError::UnknownImageFormat)?
        .decode()
        .map_err(|_| FeatureExtractionError::ImageDecodeError)?;

    Ok(strip_transparency(image, device))
}

fn resize_tensor(image: Tensor, size: (i64, i64)) -> Tensor {
    image.upsample_bicubic2d([size.0, size.1], true, None, None)
}

pub fn resize_image_by_patch_count(image: Tensor, patches: (i64, i64), patch_dim: i64) -> Tensor {
    let height = patches.0 * patch_dim;
    let width = patches.1 * patch_dim;

    resize_tensor(image.unsqueeze(0), (height, width))
}
