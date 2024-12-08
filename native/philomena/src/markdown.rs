use crate::{camo, domains};
use comrak::Options;
use std::collections::HashMap;
use std::sync::Arc;

pub fn common_options() -> Options {
    let mut options = Options::default();

    // Upstream options
    options.extension.autolink = true;
    options.extension.table = true;
    options.extension.description_lists = true;
    options.extension.superscript = true;
    options.extension.strikethrough = true;
    options.parse.smart = true;
    options.render.hardbreaks = true;
    options.render.github_pre_lang = true;
    options.render.escape = true;

    // Philomena options
    options.extension.underline = true;
    options.extension.spoiler = true;
    options.extension.greentext = true;
    options.extension.subscript = true;
    options.extension.philomena = true;
    options.render.ignore_empty_links = true;
    options.render.ignore_setext = true;

    options.extension.image_url_rewriter = Some(Arc::new(|url: &str| camo::image_url_careful(url)));

    if let Some(domains) = domains::get() {
        options.extension.link_url_rewriter = Some(Arc::new(|url: &str| {
            domains::relativize_careful(domains, url)
        }));
    }

    options
}

pub fn to_html(input: &str, reps: HashMap<String, String>) -> String {
    let mut options = common_options();
    options.extension.replacements = Some(reps);

    comrak::markdown_to_html(input, &options)
}

pub fn to_html_unsafe(input: &str, reps: HashMap<String, String>) -> String {
    let mut options = common_options();
    options.render.escape = false;
    options.render.unsafe_ = true;
    options.extension.replacements = Some(reps);

    comrak::markdown_to_html(input, &options)
}
