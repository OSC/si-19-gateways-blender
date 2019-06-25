require "sinatra/base"
require "pathname"

class App < Sinatra::Base
  set :erb, :escape_html => true

  def title
    "My App"
  end

  get "/" do
    erb :index
  end
  
  get "/jobs" do
      output = `/opt/torque/bin/qselect`
      @jobs = output.split
    
    erb :jobs
  end
  
  get "/job" do
      @jobid = params['jobid']
      @jobstats = `/opt/torque/bin/qstat -f #{@jobid}`
      @images = Dir.glob(Pathname.new(params['output']).join('*.png').to_s)
      
      erb :job
  end
  
  get "/new" do
      erb :new
  end
  
  post "/job" do
      #qsub -v BLEND_FILE_PATH="$PWD/blender_splash_fishy_cat/fishy_cat.blend" sequential_job.sh
      
      #/users/PZS0731/vshah/ondemand/data/sys/myjobs/projects/default/2/blender_splash_fishy_cat/render.sh
      #/users/PZS0731/vshah/ondemand/data/sys/myjobs/projects/default/2/blender_splash_fishy_cat/fishy_cat.blend
      
      output = `/opt/torque/bin/qsub -A PZS0731 -v BLEND_FILE_PATH=#{params[:blend_file_path]} -l nodes=1:ppn=#{params[:num_cpus]} /users/PZS0731/vshah/ondemand/data/sys/myjobs/projects/default/2/blender_splash_fishy_cat/render.sh 2>&1`
      
      output_dir = Pathname.new(params[:blend_file_path]).dirname.join('output').to_s
      jobid = output.split("\n").last
      
      redirect url("/job?jobid=#{jobid}&output=#{output_dir}")
      
  end

  get "/blend/new" do
      erb :blend_new
  end
  
  post "/blend/frames" do
      @filename = params['blendFile'][:filename]
      file = params['blendFile'][:tempfile]
      
      filepath = File.dirname(__FILE__) + "/public/#{@filename}"
    
      File.open(filepath, 'wb') do |f|
          f.write(file.read)
      end
      
      outputDir = File.dirname(__FILE__) + "/public/output_#{Pathname(@filename).sub_ext('')}_#{rand(1..1000000)}"
      walltime = "%02d:%02d:00" % [params[:num_hours], params[:num_minutes]]
      
      output = `/opt/torque/bin/qsub -A #{params['project_name']} -v BLEND_FILE_PATH=#{filepath},OUTPUT_DIR=#{outputDir},FRAMES_RANGE=#{params[:frames_range]} -l nodes=1:ppn=#{params[:num_cpus]} -l walltime=#{walltime} #{File.dirname(__FILE__) + "/render.sh"} 2>&1`
      
      redirect url("/blend/frames?output_dir=#{outputDir}")
      
  end
  
  get "/blend/frames" do
  end
  
  post "/blend/video" do
  end
  
  get "/blend/video" do
      
    #@movieLoc = "https://ondemand-test.osc.edu/pun/sys/files/api/v1/fs/users/PZS0731/vshah/ondemand/data/sys/myjobs/projects/default/2/blender_splash_fishy_cat/output/outfile.mp4"
    #users/PZS0731/vshah/ondemand/data/sys/myjobs/projects/default/2/blender_splash_fishy_cat/
    @movieLoc = "https://ondemand-test.osc.edu/pun/sys/files/api/v1/fs/users/PZS0731/vshah/ondemand/data/sys/myjobs/projects/default/2/blender_splash_fishy_cat/video7.mp4"
    
    erb :renderMovie
  end

  
end
