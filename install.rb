#!/usr/bin/env sprinkle -c -v -s
#/ Usage 
#/
#/ This is how you do things 

$stderr.sync = true

%w(config).each do |lib|
  require_relative lib
end

file = __FILE__

package :prereq_install do
  yum 'yum-utils net-tools epel-release'
  verify do
    has_yum 'yum-utils'
    has_yum 'net-tools'
    has_yum 'epel-release'
  end
end

package :add_2600_repo do
  runner "curl -k -O #{REPO_2600_URL}/#{REPO_FILENAME}", :sudo => true do
    post :install, ["yum -y install #{REPO_FILENAME}" , "yum clean all"]
  end
  verify  do
    has_file "/etc/yum.repos.d/2600Hz.repo"
  end
end

package :disable_2600_repo_experimental do
  runner "yum-config-manager --disable 2600hz-experimental"
end

package :enable_2600_repo do
  runner "yum-config-manager --enable 2600hz-stable"
end

package :misc_dependencies do
  yum 'httpd', 'rsyslog', 'git', 'pygpgme','make', 'automake', 'autoconf', 'autoconf-archive', 'curl-devel','gcc', 'gcc-c++', 'libxslt', 'zip', 'wget'
  yum 'libxml2-devel','expat-devel, openssl-devel', 'help2man', 'js-devel-1.8.5', 'libicu-devel', 'libtool', 'perl-Test-Harness'
  verify do
    has_yum 'httpd'
    has_yum 'rsyslog'
    has_yum 'git'
    has_yum 'pygpgme'
    has_yum 'make'
    has_yum 'automake'
    has_yum 'autoconf'
    has_yum 'autoconf-archive'
#    has_yum 'curl-devel'
    has_yum 'gcc'
    has_yum 'gcc-c++'
    has_yum 'libxslt'
    has_yum 'zip'
    has_yum 'help2man'
    has_yum 'js-devel'
    has_yum 'libicu-devel'
    has_yum 'libtool'
    has_yum 'openssl-devel'
    has_yum 'perl-Test-Harness'
    has_yum 'wget'
  end
end

package :add_packagecloud_repo do
  runner "curl -o /etc/yum.repos.d/imeyer_runit.repo #{REPO_PKGCLOUD_URL}", :sudo => true do
    pre :install, "test ! -f /etc/yum.repos.d/imeyer_runit.repo && sudo touch /etc/yum.repos.d/imeyer_runit.repo; echo done"
    post :install, "yum -q makecache -y --disablerepo='*' --enablerepo='imeyer_runit'"
  end
  verify { has_file "/etc/yum.repos.d/imeyer_runit.repo" }
end

package :runit_install do
  yum 'runit'
  verify { has_yum 'runit' }
end

package :bigcouch_install do
  yum 'kazoo-bigcouch'
  verify { has_yum 'kazoo-bigcouch' }
end

package :couchdb2_install do
  source "#{COUCHDB_REPO}", :sudo => false do
    prefix '/opt/couchdb'
    archives '/home/deploy'
    builds '/home/deploy/build'
    configure_command './configure'
    build_command 'make release'
    install_command 'cp -R rel/couchdb /opt'
    post :extract, 'chown -R deploy:deploy /home/deploy/build'
    pre :install, "test ! -d /opt/couchdb && sudo mkdir -p /opt/couchdb; echo done"
  end

  verify do
    has_file '/opt/couchdb/bin/couchdb'
  end
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
  yum ['kazoo-applications', 'kazoo-applications-extras, kazoo-application-*, kazoo-application-acdc, kazoo-application-notify', 'kazoo-application-hotornot']
  verify do 
    has_yum 'kazoo-applications'
#    has_yum 'kazoo-applications-extras'
#    has_yum 'kazoo-application-acdc'
#    has_yum 'kazoo-application-notify'
#    has_yum 'kazoo-application-hotornot'
  end
                                       
end

package :monster_install do
  yum ['monster-ui', 'monster-ui-application-accounts', 'monster-ui-application-callflows', 'monster-ui-application-numbers', 'monster-ui-application-voicemails', 'monster-ui-application-voip', 'monster-ui-application-webhooks']
  verify do
    has_yum 'monster-ui'
#    has_yum 'monster-ui-application-accounts'
#    has_yum 'monster-ui-application-callflows'
#    has_yum 'monster-ui-application-numbers'
#    has_yum 'monster-ui-application-voicemails'
#    has_yum 'monster-ui-application-voip'
#    has_yum 'monster-ui-application-webhooks'
  end
end

package :haproxy_cfg do
  @db_nodes = DB_NODES
  file '/etc/kazoo/haproxy/haproxy.cfg', :contents => render("haproxy.conf.erb"), :sudo => true

  verify { file_contains '/etc/kazoo/haproxy/haproxy.cfg', "#{DB_NODES.first[0]}"}
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
  push_text "1:1:sip\:#{MY_ADDRESS}\:11000:0:1: :", '/etc/kazoo/kamailio/dbtext/dispatcher', :sudo => true

  verify { file_contains '/etc/kazoo/kamailio/dbtext/dispatcher',"#{MY_ADDRESS}" }
end

package :ecallmgr_erlang_cookie do
  requires :kazoo_install
  replace_text 'change_me', "#{ERLANG_COOKIE}", '/etc/kazoo/core/config.ini', :sudo => true

  verify { file_contains '/etc/kazoo/core/config.ini', "#{ERLANG_COOKIE}"}
end

package :apps_erlang_cookie do
  requires :kazoo_install
  replace_text 'change_me', "#{ERLANG_COOKIE}", '/etc/kazoo/core/vm.args', :sudo => true

  verify { file_contains '/etc/kazoo/core/vm.args', "#{ERLANG_COOKIE}"}
end

package :freeswitch_erlang_cookie do
  requires :freeswitch_install
  replace_text 'change_me', "#{ERLANG_COOKIE}", '/etc/kazoo/freeswitch/autoload_configs/kazoo.conf.xml', :sudo => true

  verify { file_contains '/etc/kazoo/freeswitch/autoload_configs/kazoo.conf.xml', "#{ERLANG_COOKIE}"}
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

package :couchdb2_creds do
  requires :kazoo_install
  replace_text '; username = "kazoo"', "username = #{COUCHDB_USER}", '/etc/kazoo/core/config.ini', :sudo => true
  replace_text '; password = "supermegaexcellenttelephonyplatform"', "password = #{COUCHDB_PASSWD}", '/etc/kazoo/core/config.ini', :sudo => true
  verify do
    file_contains '/etc/kazoo/core/config.ini', "#{COUCHDB_USER}"
    file_contains '/etc/kazoo/core/config.ini', "#{COUCHDB_PASSWD}"
  end
end

package :turnon_haproxy do
  runner "systemctl restart kazoo-haproxy", :sudo =>true do
    pre  :install, "systemctl enable kazoo-haproxy"
    post :install, "systemctl restart kazoo-haproxy"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-haproxy.service"}
end

package :turnon_bigcouch do
  runner "systemctl restart kazoo-bigcouch", :sudo =>true do
    pre  :install, "systemctl enable kazoo-bigcouch"
    post :install, "systemctl restart kazoo-bigcouch"
  end
  
  verify {has_symlink "/etc/systemd/system/multi-user.target.wants/kazoo-bigcouch.service"}
end

package :couchdb2_init do
  requires :couchdb_logging
  file '/etc/sv/couchdb/run', :content => File.read('files/couchdb'), :sudo => true do
    pre :install, ["test ! -d /etc/sv/couchdb && sudo mkdir -p /etc/sv/couchdb; echo done", "chown -R kazoo:daemon /opt/couchdb"]
    post :install, ["chmod +x /etc/sv/couchdb/run", "test ! -d /etc/service && sudo mkdir -p /etc/service; echo done"]
  end
  verify { has_file '/etc/sv/couchdb/run'}
end

package :couchdb_logging do
  file '/etc/sv/couchdb/log/run', :content => File.read('files/couchdb_run'), :sudo => true do
    pre :install, "test ! -d /etc/sv/couchdb/log && sudo mkdir -p /etc/sv/couchdb/log; echo done"
    post :install, "chmod +x /etc/sv/couchdb/log/run"
  end
  file '/var/log/couchdb/config', :content => File.read('files/couchdb_config'), :sudo => true do
    pre :install, "test ! -d /var/log/couchdb && sudo mkdir -p /var/log/couchdb; echo done"
  end
  verify do
    has_file '/etc/sv/couchdb/log/run'
    has_file '/var/log/couchdb/config'
  end
end

package :turnon_couchdb2 do
  requires :couchdb2_init
  runner 'ln -s /etc/sv/couchdb /etc/service/couchdb', :sudo => true do
    post :install, 'sleep 10 && sudo sv start couchdb'
  end
  verify { has_symlink '/etc/service/couchdb' }
end

package :configure_couchdb2_cluster do
  runner "curl -X PUT http://127.0.0.1:5984/_users" do
  end

  runner "curl -X PUT http://127.0.0.1:5984/_replicator" do
  end

  runner "curl -X PUT http://127.0.0.1:5984/_global_changes" do
  end

  runner "curl -X PUT http://127.0.0.1:5984/_metadata" do
  end
  
  runner "curl -v -X POST http://127.0.0.1:5984/_cluster_setup -H 'Content-Type:application/json' --data '{\"action\":\"enable_cluster\",\"username\":\"admin\", \"password\":\"15ZJBKPl\", \"bind_address\":\"0.0.0.0\", \"port\":\"5984\"}'"
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
    verify {has_symlink "/etc/systemd/system/multi-user.target.wants/httpd.service"}
end

package :sleepy do
  runner "sleep 120"
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

package :iptables_rules do
  runner 'iptables -A allow_services -p tcp --dport 80 -j ACCEPT', :sudo => true
  runner 'iptables -A allow_services -p tcp --dport 8000 -j ACCEPT', :sudo => true
  runner 'iptables -A allow_services -p tcp --dport 5060 -j ACCEPT', :sudo => true
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
  # requires :prereq_install
  # requires :add_2600_repo
  # requires :enable_2600_repo
  # requires :disable_2600_repo_experimental
  # requires :misc_dependencies
  # requires :add_packagecloud_repo
  # requires :enable_2600_repo
  # requires :bigcouch_install
  # requires :runit_install
  # requires :haproxy_install
  # requires :freeswitch_install
  # requires :kamailio_install
  # requires :rabbitmq_install
  # requires :kazoo_install
  # requires :couchdb2_install
  # requires :haproxy_cfg
  # requires :kamailio_local_cfg
  # requires :ecallmgr_erlang_cookie
  # requires :freeswitch_erlang_cookie
  # requires :apps_erlang_cookie
  # requires :monster_install
  # requires :monster_config
  # requires :couchdb2_creds
  # #  requires :freeswitch_iptables_rules_v4
  # requires :turnon_httpd
  # requires :turnon_rabbit
  # requires :turnon_kamailio
  # requires :turnon_freeswitch
  # #  requires :turnon_bigcouch
  # requires :turnon_haproxy
  # requires :turnon_couchdb2
  # requires :configure_couchdb2_cluster
  # requires :turnon_apps
  # requires :turnon_ecallmgr
  # requires :sleepy
  requires :create_root_account
  requires :monster_init
  requires :iptables_rules
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
