
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function convertSpecialChars(str: string): string {
  return str
    .replace(/ß/g, 'ss')
    .replace(/ä/g, 'a')
    .replace(/ö/g, 'o')
    .replace(/ü/g, 'u')
    .replace(/Ä/g, 'A')
    .replace(/Ö/g, 'O')
    .replace(/Ü/g, 'U')
    // Remove any other special characters that might cause issues
    .replace(/[^a-zA-Z0-9-_ ]/g, '');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get all projects
    const { data: projects, error: projectsError } = await supabaseClient
      .from('projects')
      .select('name, location, folder_name')

    if (projectsError) throw projectsError

    const results = []
    
    // Create folders for each project
    for (const project of projects) {
      const folderName = project.folder_name;
      const placeholderContent = new Blob([`Project: ${project.name}\nLocation: ${project.location || 'N/A'}\nCreated: ${new Date().toISOString()}`], {
        type: 'text/plain'
      })

      try {
        // Upload the placeholder file
        const { error } = await supabaseClient.storage
          .from('projectInfo')
          .upload(`${folderName}/project-info.txt`, placeholderContent)

        results.push({
          project: folderName,
          originalName: project.name,
          success: !error,
          error: error?.message
        })
      } catch (error) {
        results.push({
          project: folderName,
          originalName: project.name,
          success: false,
          error: error.message
        })
      }
    }

    return new Response(
      JSON.stringify({ success: true, results }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
