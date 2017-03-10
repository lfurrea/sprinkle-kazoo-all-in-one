#!/usr/bin/env sprinkle -c -s
#/ Usage 
#/
#/ This is how you do things 

$stderr.sync = true

%w(config).each do |lib|
  require_relative lib
end

file = __FILE__

package :yumutils_install do
  yum 'yum-utils'
  verify { has_yum 'yum-utils' }
end

package :add_2600_repo do
  runner "curl -k -O #{REPO_URL}/#{REPO_FILENAME}", :sudo =>true do
    post :install, "rpm -Uvh #{REPO_FILENAME}" 
  end
  verify do
    has_file "/home/deploy/#{REPO_FILENAME}"
  end
end

package :enable_repo do
  runner "yum-config-manager --enable 2600hz-stable" do
    pre :install, "yum-config-manager --enable 2600hz-stable"
  end
end

package :change_hostname do
  requires :change_sysconfig
  requires :add_etc_hosts
  requires :run_hostname
end

package :change_sysconfig do
  push_text "HOSTNAME=#{MY_HOSTNAME}", '/etc/sysconfig/network', :sudo => true
  verify { file_contains '/etc/sysconfig/network', "#{MY_HOSTNAME}"}
end

package :add_etc_hosts do
  push_text "#{MY_ADDRESS} #{MY_HOSTNAME}", '/etc/hosts', :sudo => true
  verify { file_contains '/etc/hosts', "#{MY_ADDRESS} #{MY_HOSTNAME}"}
end

package :run_hostname do
runner "hostname #{MY_HOSTNAME}", :sudo =>true do
    post :install, "service network restart"
  end
#  verify { test "`hostname -f` = #{MY_HOSTNAME}" }  
end

package :misc_dependencies do
  yum 'httpd', 'rsyslog', 'git', 'make', 'automake', 'gcc', 'gcc-c++', 'libxslt', 'zip', 'libxml2-devel','expat-devel, openssl-devel'
  verify do
    has_yum 'httpd'
    has_yum 'rsyslog'
    has_yum 'git'
    has_yum 'make'
    has_yum 'automake'
    has_yum 'zip'
    has_yum 'openssl-devel'
  end
end

package :bigcouch_install do
  yum 'kazoo-bigcouch'
  verify { has_yum 'kazoo-bigcouch' }
end

package :haproxy_install do
  yum 'kazoo-haproxy'
  verify { has_yum 'kazoo-haproxy'}
end

package :freeswitch_install do
  yum 'kazoo-freeswitch'
  verify { has_yum 'kazoo-freeswitch' }
end

package :kamailio_install do
  yum 'kazoo-kamailio'
  verify { has_yum 'kazoo-kamailio'}
end

package :rabbitmq_install do
  yum 'kazoo-rabbitmq'
  verify { has_yum 'kazoo-rabbitmq'}
end

package :kazoo_install do
  yum ['kazoo-applications', 'kazoo-applications-extras']
  verify { has_yum 'kazoo-applications' }
end

package :monster_install do
  yum 'monster-ui'
  verify { has_yum 'monster-ui'}
end

package :kamailio_local_cfg do
  requires :local_cfg_replace_address
  requires :local_cfg_replace_hostname
  requires :dispatcher_add_address
end

package :local_cfg_replace_address do
  replace_text 'MY_IP_ADDRESS!.*!g', "MY_IP_ADDRESS!#{MY_ADDRESS}!g", '/etc/kazoo/kamailio/local.cfg', :sudo => true
  verify { file_contains '/etc/kazoo/kamailio/local.cfg', "MY_IP_ADDRESS!#{MY_ADDRESS}!g"}
end

package :local_cfg_replace_hostname do
  replace_text 'MY_HOSTNAME!.*!g', "MY_HOSTNAME!#{MY_HOSTNAME}!g", '/etc/kazoo/kamailio/local.cfg', :sudo => true
  verify { file_contains '/etc/kazoo/kamailio/local.cfg', "MY_HOSTNAME!#{MY_HOSTNAME}!g"}
end

package :dispatcher_add_address do
  push_text ":1:sip:#{MY_ADDRESS}:11000:0:0::aio-fs", '/etc/kazoo/kamailio/dbtext/dispatcher', :sudo => true

  verify { file_contains '/etc/kazoo/kamailio/dbtext/dispatcher',"#{MY_ADDRESS}" }
end

package :ecallmgr_erlang_cookie do
  requires :kazoo_install
  replace_text 'vXydfQQdDJQYAA', "#{ERLANG_COOKIE}", '/etc/kazoo/core/config.ini', :sudo => true

  verify { file_contains '/etc/kazoo/core/config.ini', "#{ERLANG_COOKIE}"}
end

package :freeswitch_erlang_cookie do
  requires :freeswitch_install
  replace_text 'vXydfQQdDJQYAA', "#{ERLANG_COOKIE}", '/etc/kazoo/freeswitch/autoload_configs/kazoo.conf.xml', :sudo => true

  verify { file_contains '/etc/kazoo/freeswitch/autoload_configs/kazoo.conf.xml', "#{ERLANG_COOKIE}"}
end

package :freeswitch_haproxy_link do
  runner [ 'rm -rf /etc/haproxy/haproxy.cfg', 'ln -s /etc/kazoo/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg' ], :sudo => true
  verify { has_symlink '/etc/haproxy/haproxy.cfg', '/etc/kazoo/haproxy/haproxy.cfg' }
end

package :freeswitch_configure_haproxy do
  @db_nodes = DB_NODES
  file '/etc/haproxy/haproxy.cfg', :contents => render("haproxy.conf.erb"), :sudo => true

  verify { file_contains '/etc/haproxy/haproxy.cfg', "#{DB_NODES.first[0]}"}
end

package :monster_config do
  requires :monster_install
  replace_text 'localhost', "#{MY_ADDRESS}", '/var/www/html/monster-ui/js/config.js', :sudo => true
  verify { file_contains '/var/www/html/monster-ui/js/config.js', "#{MY_ADDRESS}"}
end

package :monster_init do
  requires :monster_install
  runner "sup crossbar_maintenance init_apps /var/www/html/monster-ui/apps http://#{MY_ADDRESS}:8000/v2" do    
  end
end

package :turnon_haproxy do
  runner "systemctl restart kazoo-haproxy", :sudo =>true do
    pre  :install, "systemctl enable kazoo-haproxy"
    post :install, "systemctl restart kazoo-haproxy"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-haproxy.service"}
end

package :turnon_haproxy do
  runner "systemctl restart kazoo-bigcouch", :sudo =>true do
    pre  :install, "systemctl enable kazoo-bigcouch"
    post :install, "systemctl restart kazoo-bigcouch"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-bigcouch.service"}
end

package :turnon_freeswitch do
  runner "systemctl restart kazoo-freeswitch", :sudo =>true do
    pre  :install, "systemctl enable kazoo-freeswitch"
    post :install, "epmd -daemon", "systemctl restart kazoo-freeswitch"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-freeswitch.service"}
end

package :turnon_kamailio do
  runner "systemctl restart kazoo-kamailio", :sudo =>true do
    pre :install, "systemctl enable kazoo-kamailio"
    post :install, "epmd -daemon", "systemctl restart kazoo-kamailio"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-kamailio.service"}
end

package :turnon_rabbit do
  runner "systemctl restart kazoo-rabbitmq", :sudo =>true do
    pre :install, "systemctl enable kazoo-rabbitmq"
    post :install, "systemctl status kazoo-rabbitmq"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-rabbitmq.service"}
end

package :turnon_apps do
  runner "systemctl restart kazoo-applications", :sudo =>true do
    pre :install, "systemctl enable kazoo-applications"
    post :install, "systemctl status kazoo-applications"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-applications.service"}
end

package :turnon_ecallmgr do
  runner "sup kapps_controller start_app ecallmgr", :sudo =>true do
  end
end

package :turnon_httpd do
  runner "systemctl restart httpd", :sudo => true do
    pre :install, "systemctl enable httpd"
    post :install, "systemctl status httpd"
  end
end

package :create_root_account do
  runner "sup crossbar_maintenance create_account #{ACCOUNTNAME} #{REALM} #{USERNAME} #{PASSWORD}", :sudo => true do
  end
end

package :freeswitch_iptables_rules_v4 do
  iptables_dir = '~/iptables'
  file '~/iptables/rules.v4', :content => File.read('files/iptables.rules.v4') do
    pre :install, "test ! -d #{iptables_dir} && sudo mkdir -p #{iptables_dir}; echo done"
    post :install, "iptables-restore < ~/iptables/rules.v4"
  end

  verify { has_file '~/iptables/rules.v4'}
end

# package :copy_gitconfig do
#   iptables_dir = '~/iptables'
#   file '~/.gitconfig', :content => File.read('files/.gitconfig')

#   verify { has_file '~/iptables/rules.v4'}
# end

# package :copy_id_rsa do
#   file '~/.ssh/id_rsa', :content => File.read('files/id_rsa')

#   verify { has_file '~/.ssh/id_rsa'}
# end

policy :kazoo_all_in_one, :roles => :linode do
  requires :yumutils_install
  requires :add_2600_repo
  requires :enable_repo
  requires :change_hostname
  requires :misc_dependencies
  requires :bigcouch_install
  requires :haproxy_install
  requires :freeswitch_install
  requires :kamailio_install
  requires :rabbitmq_install
  requires :kazoo_install
  requires :kamailio_local_cfg
  requires :ecallmgr_erlang_cookie
  requires :freeswitch_erlang_cookie
  requires :monster_install
  requires :monster_config
#  requires :freeswitch_haproxy_link
#  requires :freeswitch_configure_haproxy
#  requires :freeswitch_iptables_rules_v4
  requires :turnon_haproxy
  requires :turnon_freeswitch
  requires :turnon_kamailio
  requires :turnon_rabbit
  requires :turnon_apps
#  requires :turnon_ecallmgr
  requires :turnon_httpd
  requires :create_root_account
  requires :monster_init
#  requires :copy_gitconfig
#  requires :copy_id_rsa
end

deployment do
  delivery :capistrano do
    begin
      recipes 'Capfile'
    rescue LoadError
      recipes 'deploy'
    end    
  end
end
