#
# Cookbook Name:: rsc_chef_client
# Recipe:: do_chef_client_run
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

marker "recipe_start_rightscale" do
  template "rightscale_audit_entry.erb"
end

log "  Converge from chef server node : #{node[:chef][:client][:node_name]}"

# Runs the Chef Client using runlist.json file.
execute "chef client converge" do
  command "chef-client"
end

