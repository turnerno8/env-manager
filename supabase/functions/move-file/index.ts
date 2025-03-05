import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const { bucketName, sourcePath, destinationPath } = await req.json()

    // Validate required parameters
    if (!bucketName || !sourcePath || !destinationPath) {
      return new Response(
        JSON.stringify({ 
          error: 'Missing required parameters. Please provide bucketName, sourcePath, and destinationPath' 
        }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
          status: 400 
        }
      )
    }

    console.log(`Moving file from ${sourcePath} to ${destinationPath} in bucket ${bucketName}`)

    // Initialize Supabase client with service role key
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Use the move method to relocate the file
    const { data: moveData, error: moveError } = await supabase
      .storage
      .from(bucketName)
      .move(sourcePath, destinationPath)

    if (moveError) {
      console.error('Error moving file:', moveError)
      
      // Check if the error is due to file already existing
      if (moveError.message?.includes('The resource already exists')) {
        return new Response(
          JSON.stringify({ 
            error: 'file_already_exists',
            message: 'A file with this name already exists in the destination folder.'
          }),
          { 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }, 
            status: 409 // Using 409 Conflict for resource conflicts
          }
        )
      }

      return new Response(
        JSON.stringify({ error: 'Failed to move file', details: moveError }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
      )
    }

    // After successful move, check if unsorted folder exists
    const { data: listData, error: listError } = await supabase
      .storage
      .from(bucketName)
      .list('', { 
        limit: 1,
        search: 'unsorted'
      })

    if (listError) {
      console.error('Error checking unsorted folder:', listError)
    } else if (!listData.some(item => item.name === 'unsorted')) {
      console.log('Creating unsorted folder')
      // Create an empty file to represent the folder
      const { error: createError } = await supabase
        .storage
        .from(bucketName)
        .upload('unsorted/.keep', new Uint8Array())

      if (createError) {
        console.error('Error creating unsorted folder:', createError)
      }
    }

    console.log('File moved successfully')
    return new Response(
      JSON.stringify({ 
        message: 'File moved successfully',
        data: moveData
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'An unexpected error occurred', details: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})