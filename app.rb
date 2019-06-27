require "sinatra/base"
require "pathname"
require "json"

class App < Sinatra::Base
  set :erb, :escape_html => true

  # Set the title of the web app
  def title
    "Blender"
  end

  # Homepage of app
  get "/" do
    erb :index
  end

  # Show the form to submit a new blend job
  get "/blend/new" do
      erb :blend_new
  end
  
  # Submit the blend job to the supercomputer
  post "/blend/frames" do
      
      # Get the name of the blend file uploaded by the user
      @filename = params['blendFile'][:filename]
      
      # Get the blend file contents uploaded by the user
      file = params['blendFile'][:tempfile]
      
      # Generate a time stamp
      # This will be used as a suffix for the blend file name and output directory to avoid 
      # overwriting prior blend files and output directories as the time stamp provides a unique name
      timeStamp = Time.now.strftime("%Y-%m-%d_%H:%M:%S")
      
      # The absolute path to the blend file
      filepath = File.dirname(__FILE__) + "/public/#{@filename.split(".")[0]}_#{timeStamp}.#{@filename.split(".")[1]}"
    
      # Upload the file from the :tempfile to Sinatra's public directory
      File.open(filepath, 'wb') do |f|
          f.write(file.read)
      end
      
      # Absolute path to directory where rendered frames will be stored
      outputDir = File.dirname(__FILE__) + "/public/output_#{Pathname(@filename).sub_ext('')}_#{timeStamp}"
      
      # Create a string for the walltime from the number of hours and number of minutes
      walltime = "%02d:%02d:00" % [params[:num_hours], params[:num_minutes]]
      
      # Execute the qsub command to submit the blend job to the supercomputer
      # Provide the name of the project to bill the RUs to, the absolute path to the blend file, 
      # the absolute path to the frames output directory, the range of frames to generate, 
      # the number of CPUs to use, the walltime for the job, and the bash file to run the blend command
      output = `/opt/torque/bin/qsub -A #{params['project_name']} -v BLEND_FILE_PATH=#{filepath},OUTPUT_DIR=#{outputDir},FRAMES_RANGE=#{params[:frames_range]} -l nodes=1:ppn=#{params[:num_cpus]} -l walltime=#{walltime} #{File.dirname(__FILE__) + "/render.sh"} 2>&1`
      
      # Get the job id of the qsub job above
      jobid = output.split("\n").last
      
      # Go to the frames page to display the frames as they are being generated
      # Pass the absolute path to the directory with all the rendered frames as an argument
      
      # Get the absolute path to the uploaded blend file
      uploadedfile = File.dirname(__FILE__) + "/public/" + (Pathname(@filename).sub_ext('').to_s + "_#{timeStamp}.blend")
      
      # Check if the uploaded blend file is empty
      # If the uploaded blend file is empty, go back to the form as it is not a valid blend file
      # If the uploaded blend file is not empty, go to the frames page to display the frames as they are rendering
      (FileTest.zero?(uploadedfile)) ? redirect(url("/blend/new")) : redirect(url("/blend/frames?output_dir=#{outputDir}&jobid=#{jobid}&project_name=#{params['project_name']}"))
      
  end
  
  # Display the page to show the frames as they are being generated and allow the user to render the movie
  get "/blend/frames" do
      
      @jobid = params['jobid']                                  # Get the job id from the arguments passed to this URL
      @output_dir = params['output_dir']                        # Get the absolute path to the frames output directory passed to this URL
      @jobstats = `/opt/torque/bin/qstat -f #{params[:jobid]}`  # Get the job statistics of the blender job
      @project_name = params['project_name']                    # Get the name of the project that was billed for the blender job
      
      # We only want the state of the job, so modify the job stats string to just get the job state
      # This is Q, R, or C
      # If the job is too old, then qstat will not return anything, so the ternerary operator handles that
      @jobstats = (@jobstats != "") ? @jobstats.split("job_state = ")[1][0,1] : ""
      
      # Get an array of absolute paths to all the rendered frames if the frames output directory exists
      if @output_dir 
          @images = Dir.glob(Pathname.new(@output_dir).join('*png').to_s)
      else
          @images = []
      end     
      
      erb :frames
    
    end
    
    # The AJAX in /blend/frames hits this url to get the currently generated frames, 
    # the job state, and if AJAX should keep checking for new frames
    get "/blend/framesjson" do
    
        @output_dir = params['output_dir']  # The output directory of all the frames
        
        # Get an array of absolute paths to all the rendered frames if the frames output directory ex
        if @output_dir 
            @images = Dir.glob(Pathname.new(@output_dir).join('*png').to_s)
        else
            @images = []
        end
        
        # Initialize the variable to hold the urls to all the rendered frames
        @image_urls = []
        
        # Get the statistics of the blender job
        @jobstats = `/opt/torque/bin/qstat -f #{params[:jobid]}`
        
        # We only want the state of the job, so modify the job stats string to just get the job state
        # This is Q, R, or C
        # If the job is too old, then qstat will not return anything, so the ternerary operator handles that
        @jobstats = (@jobstats != "") ? @jobstats.split("job_state = ")[1][0,1] : ""
        
        # Make the AJX refresh every 5 seconds
        @keepRefreshing = true
        
        # If the job has completed, that means the video has generated
        # The AJAX does not need to reload every 5 seconds anymore, so set @keepRefreshing to false
        if @jobstats == "C"
            @keepRefreshing = false
        end
        
        # Append the absolute paths to all the rendered frames to the file API url and add the full url into the image urls array
        # Only do this if blender has finished writing to the file or the job has completed
        for image in @images do
            @image_urls << "https://ondemand-test.osc.edu/pun/sys/files/api/v1/fs#{image}" if File.stat(image).size > 0 || @jobstats == "C"
        end
        
        # Initialize the variable to hold the text in the header status
        @header = ""
        
        # Depending on the job state, set the header text
        case @jobstats
            when "Q"
                @header = "Job Queued"
            when "R"
                @header = "Job Running"
            when "C"
                @header = "Job Completed"
        end
        
        # Since AJAX can easily read JSON objects, we will return data as a JSON object
        # Normally the return type is text/html, so we need to change it to JSON
        content_type :json
        
        # Put all the data into a hash and convert it to JSON so the AJAX can use it
        {:frameurls => @image_urls, :header => @header, :status => @keepRefreshing}.to_json
        
    end
    
  # Render the movie from the frames
  post "/blend/video" do
      
      # Store the absolute path to the directory where the frames are stored into a variable
      frames_dir = params[:frames_dir]

      # Create a string for the walltime from the number of hours and number of minutes
      walltime = "%02d:%02d:00" % [params[:num_hours], params[:num_minutes]]

      # Execute the qsub command to submit the ffmpeg job to the supercomputer
      # Provide the name of the project to bill the RUs to, the absolute path to the directory with the frames, 
      # the number of frames to use per second, the number of CPUs to use, 
      # the walltime for the job, and the bash file to run the ffmpeg command
      output = `/opt/torque/bin/qsub -A #{params['project_name']} -v FRAMES_DIR=#{frames_dir},FRAMES_PER_SEC=#{params[:frames_per_sec]} -l nodes=1:ppn=#{params[:num_cpus]} -l walltime=#{walltime} #{File.dirname(__FILE__) + "/renderVideo.sh"} 2>&1`
      
      # Get the job id of the qsub job above
      jobid = output.split("\n").last
      
      # Go to the video page to display the status of the ffmpeg job and allow the user to download the video when it is finished rendering
      # Pass the absolute path to the video file as an argument, as well as the id of the job
      redirect url("/blend/video?video_loc=#{frames_dir + '/video.mp4'}&jobid=#{jobid}")
  end
  
  # Show page to display the status of the ffmpeg job and allow the user to download the video when it is finished rendering
  get "/blend/video" do
     
    # Create a link to the files API to link to the video file using the absolute video file path provided as an argument
    @movieLoc = "https://ondemand-test.osc.edu/pun/sys/files/api/v1/fs" + params[:video_loc]
    
    # Get the job statistics of the ffmpeg job with the job id provided as an argument
    @jobstats = `/opt/torque/bin/qstat -f #{params[:jobid]}`
    
    # We only want the state of the job, so modify the job stats string to just get the job state
    # This is Q, R, or C
    # If the job is too old, then qstat will not return anything, so the ternerary operator handles that
    @jobstats = (@jobstats != "") ? @jobstats.split("job_state = ")[1][0,1] : ""
    
    # Make the page refresh every 5 seconds
    @keepRefreshing = true
    
    # If the job has completed, that means the video has generated
    # The page does not need to reload every 5 seconds anymore, so set @keepRefreshing to false
    if @jobstats == "C"
        @keepRefreshing = false
    end
    
    erb :video
  end
  
end
