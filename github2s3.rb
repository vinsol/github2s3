#!/usr/bin/ruby

#############################################################
# Requirements:
#				ruby + aws-s3 gem + colorize gem
#				git
#
# Author: Akhil Bansal (http://webonrails.com)
#############################################################


#############################################################
# CONFIGURATION SETTINGS: Please change your S3 credentials

# AWS S3 credentials


AWS_ACCESS_KEY_ID = "ACCESS_KEY"
AWS_SECRET_ACCESS_KEY = "SECRET_KEY"

# S3 bucket name to put dumps
S3_BUCKET = "github-backup"

USE_SSL = true



#############################################################
# PLEASE DO NOT EDIT BELOW THIS LINE
#############################################################


require 'rubygems'
require 'fileutils'
require  'aws/s3'
require 'yaml'
require "colorize"

REPOSITORY_FILE = File.dirname(__FILE__) + '/github_repos.yml'

AWS::S3::Base.establish_connection!(
    :access_key_id     => AWS_ACCESS_KEY_ID,
    :secret_access_key => AWS_SECRET_ACCESS_KEY,
    :use_ssl => USE_SSL
    
  )

class Bucket < AWS::S3::Bucket
end

class  S3Object < AWS::S3::S3Object
end

def  clone_and_upload_to_s3(options)
	 puts "\n\nChecking out #{options[:name]} ...".green
	 clone_command = "cd #{S3_BUCKET} && git clone --bare #{options[:clone_url]} #{options[:name]}"
   puts clone_command.yellow
   system(clone_command)
	 puts "\n Compressing #{options[:name]} ".green
	 system("cd #{S3_BUCKET} && tar czf #{compressed_filename(options[:name])} #{options[:name]}")
	 
	 upload_to_s3(compressed_filename(options[:name]))
	 
 end
 
 def compressed_filename(str)
	 str+".tar.gz"
 end	 
 
 def upload_to_s3(filename)
	 begin
		puts "** Uploading #{filename} to S3".green
		path = File.join(S3_BUCKET, filename)
		S3Object.store(filename, File.read(path), s3bucket)
	 rescue Exception => e
		puts "Could not upload #{filename} to S3".red
		puts e.message.red
	 end
 end
  
def delete_dir_and_sub_dir(dir)
  Dir.foreach(dir) do |e|
    # Don't bother with . and ..
    next if [".",".."].include? e
    fullname = dir + File::Separator + e
    if FileTest::directory?(fullname)
      delete_dir_and_sub_dir(fullname)
    else
      File.delete(fullname)
    end
  end
  Dir.delete(dir)
end

def ensure_bucket_exists
	 begin
		bucket = Bucket.find(s3bucket)
	 rescue AWS::S3::NoSuchBucket => e
		puts "Bucket '#{s3bucket}' not found."
		puts "Creating Bucket '#{s3bucket}'. "
		
		begin 
			Bucket.create(s3bucket)
			puts "Created Bucket '#{s3bucket}'. "
		rescue Exception => e
			puts e.message
		end
	 end
 
 end

def s3bucket
	s3bucket = S3_BUCKET 
end


def backup_repos_form_yaml 
    if File.exist?(REPOSITORY_FILE)
      repos = YAML.load_file(REPOSITORY_FILE)
      repos.each{|repo| clone_and_upload_to_s3(:name => repo[0], :clone_url => repo[1]['git_clone_url']) }
    else
	    puts "Repository YAML file(./github_repos.yml) file not found".red
    end
end

def back_repos_from_arguments
	ARGV.each do |arg|
		begin
			name = arg.split('/').last
			clone_and_upload_to_s3(:name => name, :clone_url => arg) 
		rescue Exception => e
			puts e.message.red
		end
	end
end


def backup_repos
	if ARGV.size > 0
		back_repos_from_arguments
	else
		backup_repos_form_yaml
	end
end	


begin
	# create temp dir
	Dir.mkdir(S3_BUCKET) rescue nil
	ensure_bucket_exists
	backup_repos
ensure	
	# remove temp dir
	delete_dir_and_sub_dir(S3_BUCKET)
end

