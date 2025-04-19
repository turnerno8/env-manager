alter table "public"."projects" alter column "status" drop default;

alter type "public"."project_status" rename to "project_status__old_version_to_be_dropped";

create type "public"."project_status" as enum ('active', 'completed', 'on_hold', 'finished-not-billed', 'finished-billed');

alter table "public"."projects" alter column status type "public"."project_status" using status::text::"public"."project_status";

alter table "public"."projects" alter column "status" set default 'active'::project_status;

drop type "public"."project_status__old_version_to_be_dropped";

alter table "public"."projects" drop column "folder_name";

alter table "public"."projects" add column "w" text;


