# Change to suit your needs
set :user, 'deploy'
role :linode, '72.14.181.17'
ssh_options[:port] = 22
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh/", "id_rsa")]

#Do not change below this line
set :run_method, :sudo
