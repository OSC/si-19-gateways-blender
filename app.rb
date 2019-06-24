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
  
end
