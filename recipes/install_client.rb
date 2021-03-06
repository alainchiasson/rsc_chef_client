#
# Cookbook Name:: rsc_chef_client
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

marker "recipe_start_rightscale" do
  template "rightscale_audit_entry.erb"
end

# Copy Chef Client installation script from cookbook files.
# Sourced from https://www.opscode.com/chef/install.sh
cookbook_file "/tmp/install.sh" do
  source "install.sh"
  mode "0755"
  cookbook "rsc_chef_client"
end

# Installs the Chef Client using user selected version.
execute "install chef client" do
  command "/tmp/install.sh -v #{node[:chef][:client][:version]}"
end

log "  Chef Client version #{node[:chef][:client][:version]} installation is" +
  " completed."

# Creates the Chef Client configuration directory.
directory node[:chef][:client][:config_dir]

# Creates the cookbooks directory.
`mkdir -p ~/cookbooks/`

# Creates the Chef Client configuration file.
template "#{node[:chef][:client][:config_dir]}/client.rb" do
  source "client.rb.erb"
  mode "0644"
  backup false
  cookbook "rsc_chef_client"
  variables(
    :server_url => node[:chef][:client][:server_url],
    :validation_name => node[:chef][:client][:validation_name],
    :node_name => node[:chef][:client][:node_name],
    :log_level => node[:chef][:client][:log_level],
    :log_location => node[:chef][:client][:log_location]
  )
end

directory "/root/.chef" do
  owner "root"
  group "root"
  mode 00600
  action :create
end

# required by knife
link "/root/.chef/knife.rb" do
  to "#{node[:chef][:client][:config_dir]}/client.rb"
end


# Creates the private key to register the Chef Client with the Chef Server.
template "#{node[:chef][:client][:config_dir]}/validation.pem" do
  source "validation_key.erb"
  mode "0600"
  backup false
  cookbook "rsc_chef_client"
  variables(
    :validation_key => node[:chef][:client][:validator_pem]
  )
end

# Creates secret key file used to decrypt data bags if they are encrypted.
file "#{node[:chef][:client][:config_dir]}/encrypted_data_bag_secret" do
  mode 0600
  content node[:chef][:client][:data_bag_secret]
  not_if { node[:chef][:client][:data_bag_secret].to_s.empty? }
end

# Creates runlist.json file.
template "#{node[:chef][:client][:config_dir]}/runlist.json" do
  source "runlist.json.erb"
  cookbook "rsc_chef_client"
  mode "0440"
  backup false
  variables(
    :node_name => node[:chef][:client][:node_name],
    :environment => node[:chef][:client][:environment],
    :company => node[:chef][:client][:company],
    :roles => "#{node[:chef][:client][:roles]}",
    :runlist => "#{node[:chef][:client][:runlist]}"
  )
end

# Sets current roles for future validation. See recipe chef::do_client_converge.
node.default[:chef][:client][:current_roles] =  node[:chef][:client][:roles]

log "  Chef Client configuration is completed."

# Sets command extensions and attributes.
extension = "--json-attributes #{node[:chef][:client][:config_dir]}/runlist.json"
extension << " --environment #{node[:chef][:client][:environment]}" \
  unless node[:chef][:client][:environment].empty?
extension << " --override-runlist #{node[:chef][:client][:runlist_override]}" \
  unless node[:chef][:client][:runlist_override].empty?


# Runs the Chef Client using command extensions.
if ("#{node[:chef][:client][:server_url]}" != "")
  execute "run chef-client" do
    command "chef-client #{extension}"
  end
else
  log "  Skipping chef-client execution as node[:chef][:client][:server_url] is undefined"
end

log "  Chef Client role(s) are: #{node[:chef][:client][:current_roles]}"

log "  Chef Client logging location: #{node[:chef][:client][:log_location]}"
log "  Chef Client logging level: #{node[:chef][:client][:log_level]}"
