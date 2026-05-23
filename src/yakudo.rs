use anyhow::{Context, Result};
use opencv::{
    core::{Mat, MatTraitConst, no_array, CV_64F},
    imgcodecs::{imdecode, IMREAD_COLOR},
    imgproc::{cvt_color, laplacian, COLOR_BGR2GRAY},
    prelude::*,
};

pub async fn fetch_image_bytes(client: &reqwest::Client, url: &str) -> Result<Vec<u8>> {
    tracing::debug!(url, "fetching image");

    let response = client
        .get(url)
        .send()
        .await
        .with_context(|| format!("failed to request image from {url}"))?
        .error_for_status()
        .with_context(|| format!("image request failed for {url}"))?;

    response
        .bytes()
        .await
        .map(|bytes| bytes.to_vec())
        .with_context(|| format!("failed to read image body from {url}"))
}

pub fn calc_yakudo_score(bytes: &[u8]) -> Result<f64> {
    let encoded = Mat::from_slice(bytes).context("failed to wrap image bytes as Mat")?;
    let image = imdecode(&encoded, IMREAD_COLOR).context("failed to decode image")?;

    if image.empty() {
        anyhow::bail!("decoded image is empty");
    }

    let mut gray = Mat::default();
    cvt_color(&image, &mut gray, COLOR_BGR2GRAY, 0).context("failed to convert image to grayscale")?;

    let mut lap = Mat::default();
    laplacian(
        &gray,
        &mut lap,
        CV_64F,
        1,
        1.0,
        0.0,
        opencv::core::BORDER_DEFAULT,
    )
    .context("failed to apply Laplacian filter")?;

    let mut mean = Mat::default();
    let mut stddev = Mat::default();
    opencv::core::mean_std_dev(&lap, &mut mean, &mut stddev, &no_array())
        .context("failed to calculate mean and standard deviation")?;

    let variance = stddev
        .at_2d::<f64>(0, 0)
        .context("failed to read standard deviation")?
        .powi(2);

    Ok(if variance == 0.0 {
        f64::INFINITY
    } else {
        5000.0 / variance
    })
}
