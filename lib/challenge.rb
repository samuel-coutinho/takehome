require 'json'

# First create the classes to be used

# Class to read a json file and parse it to a hash
class ParseJsonFile
  def initialize(path)
    @path = path
  end

  def parse_file
    begin
      file = File.read(@path)
      parsed = JSON.parse(file)
    rescue Errno::ENOENT
      abort "File '#{@path}' not found"
    rescue JSON::ParserError
      abort "Error parsing JSON file: '#{@path}'"
    end

    parsed
  end
end

# Aplies the logic to create the list for the output file
class CreateCompanyList
  def initialize(**attrs)
    @users = attrs.fetch(:users, [])
    @companies = attrs.fetch(:companies, [])

    @users = @users.sort_by! { |user| user['last_name'] }
    @companies = @companies.sort_by! { |company| company['id'] }
  end

  # Assing the company email lists and calculate the Total amount of top ups
  def create_list
    @companies.each do |company|
      users_mailed, users_not_mailed = update_users_tokens(company)

      company['users_mailed'] = users_mailed
      company['users_not_mailed'] = users_not_mailed

      total_top_ups = (users_mailed.length + users_not_mailed.length) * company['top_up']

      company['total_top_ups'] = total_top_ups
    end

    @companies
  end

  # Handle the company email lists and update the users tokens
  def update_users_tokens(company)
    users_mailed = []
    users_not_mailed = []

    @users.each do |user|
      next unless user['company_id'] == company['id'] && user['active_status']

      user['new_token_balance'] = user['tokens'] + company['top_up']
      if user['email_status'] && company['email_status']
        users_mailed.push(user)
      else
        users_not_mailed.push(user)
      end
    end
    [users_mailed, users_not_mailed]
  end
end

# Create the output file and add the content to it
class CreateOutputFile
  def initialize(**attrs)
    @file_name = attrs.fetch(:file_name, 'output.txt')
    @companies = attrs.fetch(:companies, [])
  end

  def create_file
    return p "File '#{@file_name}' already exists!" if File.exist?(@file_name)

    Dir.mkdir('files') unless Dir.exist?('files')

    File.open("files/#{@file_name}", 'w') do |file|
      @companies.each do |company|
        next unless (company['total_top_ups']).positive?

        file.puts
        file.puts "  Company Id: #{company['id']}"
        file.puts "  Company Name: #{company['name']}"
        file.puts '  Users Emailed:'

        write_user_list(company['users_mailed'], file)

        file.puts '  Users Not Emailed:'

        write_user_list(company['users_not_mailed'], file)

        file.print "    Total amount of top ups for #{company['name']}: "
        file.puts company['total_top_ups']
      end
    end

    p "File '#{@file_name}' created!"
  end

  # Reusable logic to handle the output of the email lists
  def write_user_list(users, file)
    users.each do |user|
      file.print "    #{user['last_name']}, "
      file.print "#{user['first_name']}, "
      file.puts user['email'].to_s
      file.puts "      Previous Token Balance, #{user['tokens']}"
      file.puts "      New Token Balance #{user['new_token_balance']}"
    end
  end
end

# Call the classes to read the file, aplly the logic and create the output file
users = ParseJsonFile.new('lib/users.json').parse_file

companies = ParseJsonFile.new('lib/companies.json').parse_file

companies_list = CreateCompanyList.new(users: users, companies: companies).create_list

CreateOutputFile.new(companies: companies_list).create_file
