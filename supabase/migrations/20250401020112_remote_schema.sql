create table "public"."project_contacts" (
    "id" uuid not null default gen_random_uuid(),
    "project_id" uuid not null,
    "name" text not null,
    "email" text,
    "phone" text,
    "description" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
);


alter table "public"."project_contacts" enable row level security;

CREATE UNIQUE INDEX project_contacts_pkey ON public.project_contacts USING btree (id);

alter table "public"."project_contacts" add constraint "project_contacts_pkey" PRIMARY KEY using index "project_contacts_pkey";

alter table "public"."project_contacts" add constraint "project_contacts_project_id_fkey" FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE not valid;

alter table "public"."project_contacts" validate constraint "project_contacts_project_id_fkey";

grant delete on table "public"."project_contacts" to "anon";

grant insert on table "public"."project_contacts" to "anon";

grant references on table "public"."project_contacts" to "anon";

grant select on table "public"."project_contacts" to "anon";

grant trigger on table "public"."project_contacts" to "anon";

grant truncate on table "public"."project_contacts" to "anon";

grant update on table "public"."project_contacts" to "anon";

grant delete on table "public"."project_contacts" to "authenticated";

grant insert on table "public"."project_contacts" to "authenticated";

grant references on table "public"."project_contacts" to "authenticated";

grant select on table "public"."project_contacts" to "authenticated";

grant trigger on table "public"."project_contacts" to "authenticated";

grant truncate on table "public"."project_contacts" to "authenticated";

grant update on table "public"."project_contacts" to "authenticated";

grant delete on table "public"."project_contacts" to "service_role";

grant insert on table "public"."project_contacts" to "service_role";

grant references on table "public"."project_contacts" to "service_role";

grant select on table "public"."project_contacts" to "service_role";

grant trigger on table "public"."project_contacts" to "service_role";

grant truncate on table "public"."project_contacts" to "service_role";

grant update on table "public"."project_contacts" to "service_role";

create policy "Office and Owner can delete project_contacts"
on "public"."project_contacts"
as permissive
for delete
to authenticated
using (((( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'office'::user_role) OR (( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'owner'::user_role)));


create policy "Office and Owner can insert project_contacts"
on "public"."project_contacts"
as permissive
for insert
to authenticated
with check (((( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'office'::user_role) OR (( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'owner'::user_role)));


create policy "Office and Owner can update project_contacts"
on "public"."project_contacts"
as permissive
for update
to authenticated
using (((( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'office'::user_role) OR (( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'owner'::user_role)));


create policy "Teamleads can read project_contacts"
on "public"."project_contacts"
as permissive
for select
to authenticated
using (((( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'teamlead'::user_role) OR (( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'office'::user_role) OR (( SELECT user_roles.role
   FROM user_roles
  WHERE (user_roles.user_id = auth.uid())) = 'owner'::user_role)));


CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.project_contacts FOR EACH ROW EXECUTE FUNCTION handle_updated_at();


