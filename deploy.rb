# Change to suit your needs
set :user, 'deploy'
role :linode, '103.215.162.70'
ssh_options[:port] = 22
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh/", "id_rsa")]

#Do not change below this line
set :run_method, :sudo
