

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."project_status" AS ENUM (
    'active',
    'completed',
    'on_hold'
);


ALTER TYPE "public"."project_status" OWNER TO "postgres";


CREATE TYPE "public"."supported_language" AS ENUM (
    'en',
    'de',
    'ro'
);


ALTER TYPE "public"."supported_language" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'owner',
    'office',
    'teamlead'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_role"("user_id" "uuid") RETURNS "public"."user_role"
    LANGUAGE "sql" SECURITY DEFINER
    AS $_$
    SELECT role FROM public.user_roles WHERE public.user_roles.user_id = $1;
$_$;


ALTER FUNCTION "public"."get_user_role"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_folder_access"("user_id" "uuid", "folder_type" "text", "access_type" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
BEGIN
    -- Owner has full access to everything
    IF (SELECT role FROM public.user_roles WHERE public.user_roles.user_id = $1) = 'owner' THEN
        RETURN TRUE;
    END IF;

    -- Office role permissions
    IF (SELECT role FROM public.user_roles WHERE public.user_roles.user_id = $1) = 'office' THEN
        IF folder_type IN ('purchaseInvoices', 'projectInfo') THEN
            RETURN TRUE;
        END IF;
        -- Read-only access to customerInfo
        IF folder_type = 'customerInfo' AND access_type = 'read' THEN
            RETURN TRUE;
        END IF;
    END IF;

    -- Teamlead role permissions
    IF (SELECT role FROM public.user_roles WHERE public.user_roles.user_id = $1) = 'teamlead' THEN
        IF folder_type = 'projectInfo' THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$_$;


ALTER FUNCTION "public"."has_folder_access"("user_id" "uuid", "folder_type" "text", "access_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_language"("p_language" "public"."supported_language") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO user_language_preferences (user_id, language)
    VALUES (auth.uid(), p_language)
    ON CONFLICT (user_id)
    DO UPDATE SET 
        language = EXCLUDED.language,
        updated_at = NOW();
END;
$$;


ALTER FUNCTION "public"."update_user_language"("p_language" "public"."supported_language") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" "text",
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "first_name" "text",
    "last_name" "text"
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."projects" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "location" "text",
    "status" "public"."project_status" DEFAULT 'active'::"public"."project_status",
    "start_date" "date",
    "end_date" "date",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "folder_name" "text" NOT NULL
);


ALTER TABLE "public"."projects" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."time_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "worker_id" "uuid" NOT NULL,
    "project_id" "uuid" NOT NULL,
    "date" "date" NOT NULL,
    "start_time" time without time zone NOT NULL,
    "end_time" time without time zone NOT NULL,
    "break_duration_minutes" integer DEFAULT 0,
    "notes" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."time_entries" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."translations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "key" "text" NOT NULL,
    "language" "public"."supported_language" NOT NULL,
    "translation" "text" NOT NULL,
    "context" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."translations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_language_preferences" (
    "user_id" "uuid" NOT NULL,
    "language" "public"."supported_language" DEFAULT 'en'::"public"."supported_language" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_language_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "public"."user_role" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."workers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."workers" OWNER TO "postgres";


ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."projects"
    ADD CONSTRAINT "projects_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."time_entries"
    ADD CONSTRAINT "time_entries_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."translations"
    ADD CONSTRAINT "translations_key_language_key" UNIQUE ("key", "language");



ALTER TABLE ONLY "public"."translations"
    ADD CONSTRAINT "translations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_language_preferences"
    ADD CONSTRAINT "user_language_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."workers"
    ADD CONSTRAINT "workers_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_user_roles_user_id" ON "public"."user_roles" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."projects" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."time_entries" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "handle_updated_at" BEFORE UPDATE ON "public"."workers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."time_entries"
    ADD CONSTRAINT "time_entries_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."time_entries"
    ADD CONSTRAINT "time_entries_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "public"."projects"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."time_entries"
    ADD CONSTRAINT "time_entries_worker_id_fkey" FOREIGN KEY ("worker_id") REFERENCES "public"."workers"("id");



ALTER TABLE ONLY "public"."user_language_preferences"
    ADD CONSTRAINT "user_language_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



CREATE POLICY "Allow office and owner roles to delete workers" ON "public"."workers" FOR DELETE TO "authenticated" USING ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = ANY (ARRAY['owner'::"public"."user_role", 'office'::"public"."user_role"])));



CREATE POLICY "Allow office and owner roles to insert projects" ON "public"."projects" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = ANY (ARRAY['owner'::"public"."user_role", 'office'::"public"."user_role"])));



CREATE POLICY "Allow office and owner roles to insert workers" ON "public"."workers" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = ANY (ARRAY['owner'::"public"."user_role", 'office'::"public"."user_role"])));



CREATE POLICY "Allow office and owner roles to update projects" ON "public"."projects" FOR UPDATE TO "authenticated" USING ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = ANY (ARRAY['owner'::"public"."user_role", 'office'::"public"."user_role"])));



CREATE POLICY "Allow office and owner roles to update time entries" ON "public"."time_entries" FOR UPDATE TO "authenticated" USING ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = ANY (ARRAY['owner'::"public"."user_role", 'office'::"public"."user_role"])));



CREATE POLICY "Allow office and owner roles to update workers" ON "public"."workers" FOR UPDATE TO "authenticated" USING ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = ANY (ARRAY['owner'::"public"."user_role", 'office'::"public"."user_role"])));



CREATE POLICY "Allow read access to all authenticated users" ON "public"."projects" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow read access to all authenticated users" ON "public"."time_entries" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow read access to all authenticated users" ON "public"."workers" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Allow teamlead role to insert workers" ON "public"."workers" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = 'teamlead'::"public"."user_role"));



CREATE POLICY "Allow teamlead, office and owner roles to insert time entries" ON "public"."time_entries" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "user_roles"."role"
   FROM "public"."user_roles"
  WHERE ("user_roles"."user_id" = "auth"."uid"())) = ANY (ARRAY['owner'::"public"."user_role", 'office'::"public"."user_role", 'teamlead'::"public"."user_role"])));



CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view own profile" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."projects" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."time_entries" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."translations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "translations_read_policy" ON "public"."translations" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."user_language_preferences" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_language_preferences_insert_policy" ON "public"."user_language_preferences" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "user_language_preferences_read_policy" ON "public"."user_language_preferences" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "user_language_preferences_update_policy" ON "public"."user_language_preferences" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_read_own_role" ON "public"."user_roles" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."workers" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";




















































































































































































GRANT ALL ON FUNCTION "public"."get_user_role"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_role"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_role"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."has_folder_access"("user_id" "uuid", "folder_type" "text", "access_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."has_folder_access"("user_id" "uuid", "folder_type" "text", "access_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_folder_access"("user_id" "uuid", "folder_type" "text", "access_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_language"("p_language" "public"."supported_language") TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_language"("p_language" "public"."supported_language") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_language"("p_language" "public"."supported_language") TO "service_role";


















GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."projects" TO "anon";
GRANT ALL ON TABLE "public"."projects" TO "authenticated";
GRANT ALL ON TABLE "public"."projects" TO "service_role";



GRANT ALL ON TABLE "public"."time_entries" TO "anon";
GRANT ALL ON TABLE "public"."time_entries" TO "authenticated";
GRANT ALL ON TABLE "public"."time_entries" TO "service_role";



GRANT ALL ON TABLE "public"."translations" TO "anon";
GRANT ALL ON TABLE "public"."translations" TO "authenticated";
GRANT ALL ON TABLE "public"."translations" TO "service_role";



GRANT ALL ON TABLE "public"."user_language_preferences" TO "anon";
GRANT ALL ON TABLE "public"."user_language_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."user_language_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."workers" TO "anon";
GRANT ALL ON TABLE "public"."workers" TO "authenticated";
GRANT ALL ON TABLE "public"."workers" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
