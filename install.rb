#!/usr/bin/env sprinkle -c -s
#/ Usage 
#/
#/ This is how you do things 

$stderr.sync = true

%w(config).each do |lib|
  require_relative lib
end

file = __FILE__

package :add_2600_repo do
  runner "curl -o /etc/yum.repos.d/2600hz.repo #{REPO}", :sudo =>true do
    post :install, "yum clean expire-cache"
  end
  verify {has_file "/etc/yum.repos.d/2600hz.repo"}
end

package :change_hostname do
  requires :change_sysconfig
  requires :add_etc_hosts
  requires :run_hostname
end

package :change_sysconfig do
  replace_text 'localhost.localdomain', "#{MY_HOSTNAME}", '/etc/sysconfig/network', :sudo => true
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
  verify {test "`hostname -f` = #{MY_HOSTNAME}"}  
end

package :bigcouch_install do
  yum 'kazoo-bigcouch-R15B'
  verify { has_yum 'kazoo-bigcouch-R15B' }
end

package :kazoo_install do
  yum 'kazoo-R15B'
  verify { has_yum 'kazoo-R15B' }
end

package :kamailio_install do
  yum 'kazoo-kamailio'
  verify { has_yum 'kazoo-kamailio'}
end

package :kamailio_local_cfg do
  requires :local_cfg_replace_address
  requires :local_cfg_replace_hostname
end

package :local_cfg_replace_address do
  replace_text 'MY_IP_ADDRESS!.*!g', "MY_IP_ADDRESS!#{MY_ADDRESS}!g", '/etc/kazoo/kamailio/local.cfg', :sudo => true
  verify { file_contains '/etc/kazoo/kamailio/local.cfg', "MY_IP_ADDRESS!#{MY_ADDRESS}!g"}
end

package :local_cfg_replace_hostname do
  replace_text 'MY_HOSTNAME!.*!g', "MY_HOSTNAME!#{MY_HOSTNAME}!g", '/etc/kazoo/kamailio/local.cfg', :sudo => true
  verify { file_contains '/etc/kazoo/kamailio/local.cfg', "MY_HOSTNAME!#{MY_HOSTNAME}!g"}
end

package :misc_dependencies do
  yum 'httpd', 'rsyslog', 'git', 'make', 'automake', 'gcc', 'gcc-c++', 'libxslt', 'zip', 'libxml2-devel','expat-devel, openssl-devel'
  verify do
    has_yum 'httpd'
    has_yum 'rsyslog'
    has_yum 'git'
    has_yum 'make'
    has_yum 'automake'
    has_yum 'gcc'
    has_yum 'gcc-c++'
    has_yum 'libxslt'
    has_yum 'zip'
    has_yum 'libxml2-devel'
    has_yum 'expat-devel'
    has_yum 'openssl-devel'
  end
end

package :ecallmgr_erlang_cookie do
  requires :kazoo_install
  replace_text 'change_me', "#{ERLANG_COOKIE}", '/etc/kazoo/config.ini', :sudo => true

  verify { file_contains '/etc/kazoo/config.ini', "#{ERLANG_COOKIE}"}
end

package :freeswitch_erlang_cookie do
  requires :freeswitch_install
  replace_text 'change_me', "#{ERLANG_COOKIE}", '/etc/kazoo/freeswitch/autoload_configs/kazoo.conf.xml', :sudo => true

  verify { file_contains '/etc/kazoo/freeswitch/autoload_configs/kazoo.conf.xml', "#{ERLANG_COOKIE}"}
end

package :freeswitch_install do
  yum 'kazoo-freeswitch-R15B'
  verify { has_yum 'kazoo-freeswitch-R15B' }
end

package :haproxy_install do
  yum 'haproxy'
  verify { has_yum 'haproxy'}
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

package :turnon_haproxy do
  runner "chkconfig haproxy on", :sudo =>true do
    post :install, "service haproxy restart"
  end
  
  verify {has_symlink "/etc/rc2.d/*haproxy"}
end

package :turnon_freeswitch do
  runner "chkconfig freeswitch on", :sudo =>true do
    post :install, "epmd -daemon", "service freeswitch restart"
  end
  
  verify {has_symlink "/etc/rc2.d/*freeswitch"}
end

package :turnon_whapps do
  runner "chkconfig kz-whistle_apps on", :sudo =>true do
    pre :install, "chkconfig --add kz-whistle_apps"
    post :install, "service kz-whistle_apps restart"
  end
  
  verify {has_symlink "/etc/rc2.d/*kz-whistle_apps"}
end

package :turnon_ecallmgr do
  runner "chkconfig kz-ecallmgr on", :sudo =>true do
    pre :install, "chkconfig --add kz-ecallmgr"
    post :install, "service kz-ecallmgr restart"
  end
  
  verify {has_symlink "/etc/rc2.d/*kz-ecallmgr"}
end

package :turnon_rabbit do
  runner "chkconfig rabbitmq-server on", :sudo =>true do
    pre :install, "chkconfig --add rabbitmq-server"
    post :install, "service rabbitmq-server restart"
  end
  
  verify {has_symlink "/etc/rc2.d/*rabbitmq-server"}
end

# package :create_root_account do
#   runner "/opt/kazoo/utils/sup/sup crossbar_maintenance create_account #{ACCOUNTNAME} #{REALM} #{USERNAME} #{PASSWORD}"
#   , :sudo => true do
    
#   end
# end

package :freeswitch_iptables_rules_v4 do
  iptables_dir = '~/iptables'
  file '~/iptables/rules.v4', :content => File.read('files/iptables.rules.v4') do
    pre :install, "test ! -d #{iptables_dir} && sudo mkdir -p #{iptables_dir}; echo done"
    post :install, "iptables-restore < ~/iptables/rules.v4"
  end

  verify { has_file '~/iptables/rules.v4'}
end

package :copy_gitconfig do
  iptables_dir = '~/iptables'
  file '~/.gitconfig', :content => File.read('files/.gitconfig')

  verify { has_file '~/iptables/rules.v4'}
end

package :copy_id_rsa do
  file '~/.ssh/id_rsa', :content => File.read('files/id_rsa')

  verify { has_file '~/.ssh/id_rsa'}
end

policy :kazoo_all_in_one, :roles => :linode do
  requires :add_2600_repo
  requires :change_hostname
  requires :bigcouch_install
  requires :kazoo_install
  requires :kamailio_install
  requires :kamailio_local_cfg
  requires :misc_dependencies
  requires :ecallmgr_erlang_cookie
  requires :freeswitch_install
  requires :freeswitch_erlang_cookie
  requires :haproxy_install
  requires :freeswitch_haproxy_link
  requires :freeswitch_configure_haproxy
#  requires :freeswitch_iptables_rules_v4
  requires :turnon_haproxy
  requires :turnon_freeswitch
  requires :turnon_ecallmgr
  requires :turnon_whapps
  requires :turnon_rabbit
  #  requires :create_root_account
  requires :copy_gitconfig
  requires :copy_id_rsa
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
