DATABASE ?= philomena
ELASTICDUMP ?= elasticdump
.ONESHELL:

all: import_es

import_es: dump_jsonl
	$(ELASTICDUMP) --input=images.jsonl --output=http://localhost:9200/ --output-index=images --limit 10000 --retryAttempts=5 --type=data --transform="doc._source = Object.assign({},doc); doc._id = doc.id"

dump_jsonl: metadata true_uploaders uploaders deleters galleries tags sources hides upvotes downvotes faves tag_names
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'copy (select temp_images.jsonb_object_agg(object) from temp_images.image_search_json group by image_id) to stdout;' > images.jsonl
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<< 'drop schema temp_images cascade;'
	sed -i images.jsonl -e 's/\\\\/\\/g'

metadata: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select id, jsonb_build_object(
			'approved', approved,
			'animated', is_animated,
			'anonymous', anonymous,
			'aspect_ratio', nullif(image_aspect_ratio, 'NaN'::float8),
			'comment_count', comments_count,
			'created_at', created_at,
			'deletion_reason', deletion_reason,
			'description', description,
			'downvotes', downvotes_count,
			'duplicate_id', duplicate_id,
			'duration', (case when is_animated then image_duration else 0::float end),
			'faves', faves_count,
			'file_name', image_name,
			'fingerprint', fingerprint,
			'first_seen_at', first_seen_at,
			'height', image_height,
			'hidden_from_users', hidden_from_users,
			'id', id,
			'ip', ip,
			'mime_type', image_mime_type,
			'orig_sha512_hash', image_orig_sha512_hash,
			'original_format', image_format,
			'pixels', cast(image_width as bigint)*cast(image_height as bigint),
			'processed', processed,
			'score', score,
			'size', image_size,
			'sha512_hash', image_sha512_hash,
			'thumbnails_generated', thumbnails_generated,
			'updated_at', updated_at,
			'upvotes', upvotes_count,
			'width', image_width,
			'wilson_score', temp_images.wilson_995(upvotes_count, downvotes_count)
		) from images;
	SQL

true_uploaders: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select i.id, jsonb_build_object('true_uploader_id', u.id, 'true_uploader', u.name) from images i left join users u on u.id = i.user_id;
	SQL

uploaders: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select i.id, jsonb_build_object('uploader_id', (case when i.anonymous = 't' then null else u.id end), 'uploader', (case when i.anonymous = 't' then null else lower(u.name) end)) from images i left join users u on u.id = i.user_id;
	SQL

deleters: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select i.id, jsonb_build_object('deleted_by_user_id', u.id, 'deleted_by_user', lower(u.name)) from images i left join users u on u.id = i.deleted_by_id;
	SQL

galleries: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select gi.image_id, jsonb_build_object('gallery_interactions', jsonb_agg(jsonb_build_object('id', gi.gallery_id, 'position', gi.position))) from gallery_interactions gi group by image_id;
	SQL

tags: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select it.image_id, jsonb_build_object(
			'tag_ids', jsonb_agg(it.tag_id),
			'tag_count', count(*),
			'error_tag_count', count(case when t.category = 'error' then t.category else null end),
			'rating_tag_count', count(case when t.category = 'rating' then t.category else null end),
			'origin_tag_count', count(case when t.category = 'origin' then t.category else null end),
			'character_tag_count', count(case when t.category = 'character' then t.category else null end),
			'oc_tag_count', count(case when t.category = 'oc' then t.category else null end),
			'species_tag_count', count(case when t.category = 'species' then t.category else null end),
			'body_type_tag_count', count(case when t.category = 'body-type' then t.category else null end),
			'content_fanmade_tag_count', count(case when t.category = 'content-fanmade' then t.category else null end),
			'content_official_tag_count', count(case when t.category = 'content-official' then t.category else null end),
			'spoiler_tag_count', count(case when t.category = 'spoiler' then t.category else null end),
		) from image_taggings it inner join tags t on t.id = it.tag_id group by image_id;
	SQL

sources: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select s.image_id, jsonb_build_object('source_url', jsonb_agg(lower(s.source)), 'source_count', count(*)) from image_sources s group by image_id;
	SQL

hides: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select ih.image_id, jsonb_build_object('hidden_by_user_ids', jsonb_agg(ih.user_id), 'hidden_by_users', jsonb_agg(lower(u.name))) from image_hides ih inner join users u on u.id = ih.user_id group by image_id;
	SQL

downvotes: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select iv.image_id, jsonb_build_object('downvoter_ids', jsonb_agg(iv.user_id), 'downvoters', jsonb_agg(lower(u.name))) from image_votes iv inner join users u on u.id = iv.user_id where iv.up = false group by image_id;
	SQL

upvotes: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select iv.image_id, jsonb_build_object('upvoter_ids', jsonb_agg(iv.user_id), 'upvoters', jsonb_agg(lower(u.name))) from image_votes iv inner join users u on u.id = iv.user_id where iv.up = true group by image_id;
	SQL

faves: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select if.image_id, jsonb_build_object('favourited_by_user_ids', jsonb_agg(if.user_id), 'favourited_by_users', jsonb_agg(lower(u.name))) from image_faves if inner join users u on u.id = if.user_id group by image_id;
	SQL

tag_names: tags_with_aliases
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		insert into temp_images.image_search_json (image_id, object) select image_id, jsonb_build_object('namespaced_tags', jsonb_build_object('name', jsonb_agg(lower(tag_name)))) from temp_images.tags_with_aliases group by image_id;
	SQL

tags_with_aliases: image_search_json
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		create unlogged table if not exists temp_images.tags_with_aliases (image_id bigint not null, tag_name text not null);
		truncate temp_images.tags_with_aliases;
		insert into temp_images.tags_with_aliases (image_id, tag_name) select it.image_id, t.name from image_taggings it inner join tags t on t.id = it.tag_id;
		insert into temp_images.tags_with_aliases (image_id, tag_name) select it.image_id, t.name from image_taggings it left outer join tags t on t.aliased_tag_id = it.tag_id where t.name is not null;
	SQL

image_search_json:
	psql $(DATABASE) -v ON_ERROR_STOP=1 <<-SQL
		drop schema if exists temp_images cascade;
		create schema temp_images;
		create unlogged table temp_images.image_search_json (image_id bigint not null, object jsonb not null);
		create function temp_images.wilson_995(succ bigint, fail bigint) returns double precision as '
		declare
			n double precision;
			p_hat double precision;
			z double precision;
			z2 double precision;
		begin
			if succ <= 0 then
				return 0;
			end if;

			n := succ + fail;
			p_hat := succ / n;
			z := 2.57583;
			z2 := 6.634900189;

			return (p_hat + z2 / (2 * n) - z * sqrt((p_hat * (1 - p_hat) + z2 / (4 * n)) / n)) / (1 + z2 / n);
		end
		' language plpgsql;
		create aggregate temp_images.jsonb_object_agg(jsonb) (sfunc = 'jsonb_concat', stype = jsonb, initcond='{}');
	SQL
