use crate::{camo, domains};
use comrak::{Arena, Options, nodes::NodeValue, parse_document};
use std::collections::HashMap;
use std::sync::Arc;

pub fn common_options() -> Options<'static> {
    let mut options = Options::default();

    // Upstream options
    options.extension.autolink = true;
    options.extension.table = true;
    options.extension.description_lists = true;
    options.extension.superscript = true;
    options.extension.strikethrough = true;
    options.parse.ignore_setext = true;
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

    options.extension.image_url_rewriter = Some(Arc::new(|url: &str| camo::image_url(url)));

    if let Some(domains) = domains::get() {
        options.extension.link_url_rewriter =
            Some(Arc::new(|url: &str| domains::relativize(domains, url)));
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
    options.render.r#unsafe = true;
    options.extension.replacements = Some(reps);

    comrak::markdown_to_html(input, &options)
}

pub fn links(input: &str) -> Vec<String> {
    let arena = Arena::new();
    let options = common_options();
    let root = parse_document(&arena, input, &options);

    root.descendants()
        .filter_map(|node| match &node.data.borrow().value {
            NodeValue::Link(link) | NodeValue::Image(link) => Some(link.url.clone()),
            _ => None,
        })
        .collect()
}

pub fn has_image(input: &str) -> bool {
    let arena = Arena::new();
    let options = common_options();
    let root = parse_document(&arena, input, &options);

    root.descendants()
        .any(|node| matches!(node.data.borrow().value, NodeValue::Image(_)))
}
