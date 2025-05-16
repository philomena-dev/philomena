const numericProperty = Symbol('numeric');
const literalProperty = Symbol('literal');
const dateProperty = Symbol('date');

const booleanPropertyValues = ['true', 'false'];

export type PropertyTypeOrValues = symbol | string[];

const imageSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['animated', booleanPropertyValues],
  ['aspect_ratio', numericProperty],
  ['body_type_tag_count', numericProperty],
  ['character_tag_count', numericProperty],
  ['comment_count', numericProperty],
  ['content_fanmade_tag_count', numericProperty],
  ['content_official_tag_count', numericProperty],
  ['created_at', dateProperty],
  ['description', literalProperty],
  ['downvotes', numericProperty],
  ['duplicate_id', numericProperty],
  ['duration', numericProperty],
  ['error_tag_count', numericProperty],
  ['faved_by', literalProperty],
  ['faved_by_id', numericProperty],
  ['faves', numericProperty],
  ['file_name', literalProperty],
  ['first_seen_at', dateProperty],
  ['height', numericProperty],
  ['id', numericProperty],
  ['mime_type', literalProperty],
  ['my', ['comments', 'faves', 'uploads', 'upvotes', 'watched']],
  ['oc_tag_count', numericProperty],
  ['orig_sha512_hash', literalProperty],
  ['orig_size', numericProperty],
  ['original_format', literalProperty],
  ['pixels', numericProperty],
  ['processed', booleanPropertyValues],
  ['rating_tag_count', numericProperty],
  ['score', numericProperty],
  ['sha512_hash', literalProperty],
  ['size', numericProperty],
  ['source_count', numericProperty],
  ['source_url', literalProperty],
  ['species_tag_count', numericProperty],
  ['spoiler_tag_count', numericProperty],
  ['tag_count', numericProperty],
  ['thumbnails_generated', booleanPropertyValues],
  ['updated_at', dateProperty],
  ['uploader', literalProperty],
  ['uploader_id', numericProperty],
  ['upvotes', numericProperty],
  ['width', numericProperty],
  ['wilson_score', numericProperty],
]);

const tagSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['alias_of', literalProperty],
  ['aliased', literalProperty],
  ['aliases', literalProperty],
  ['analyzed_name', literalProperty],
  ['category', literalProperty],
  ['description', literalProperty],
  ['id', numericProperty],
  ['images', numericProperty],
  ['implied_by', literalProperty],
  ['implies', literalProperty],
  ['name', literalProperty],
  ['name_in_namespace', literalProperty],
  ['namespace', literalProperty],
  ['short_description', literalProperty],
  ['slug', literalProperty],
]);

const commentSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['author', literalProperty],
  ['body', literalProperty],
  ['created_at', dateProperty],
  ['id', numericProperty],
  ['image_id', literalProperty],
  ['my', ['comments']],
  ['user_id', literalProperty],
]);

const forumSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['author', literalProperty],
  ['body', literalProperty],
  ['created_at', dateProperty],
  ['id', numericProperty],
  ['my', ['posts']],
  ['subject', literalProperty],
  ['topic_id', literalProperty],
  ['topic_position', numericProperty],
  ['updated_at', dateProperty],
  ['user_id', literalProperty],
  ['forum', literalProperty],
]);

const rangeOperators = ['gt', 'gte', 'lt', 'lte'];

export const propertyTypeOperators = new Map<symbol, string[]>([
  [numericProperty, rangeOperators],
  [dateProperty, rangeOperators],
]);

export const searchTypeToPropertiesMap = new Map<string, Map<string, PropertyTypeOrValues>>([
  ['cq', commentSearchProperties],
  ['fq', forumSearchProperties],
  ['tq', tagSearchProperties],
  ['q', imageSearchProperties],
]);
