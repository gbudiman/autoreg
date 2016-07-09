class Mech
  MASTER_ACCOUNT_PATH = Rails.root.join('config', 'master_account.yml').to_s
  CRAWL_PATH = Rails.root.join('config', 'crawl_path.yml').to_s
  LOGIN_URL = 'https://webreg.usc.edu'

  attr_reader :account, :crawl

  def initialize
    @account = YAML.load_file(MASTER_ACCOUNT_PATH).symbolize_keys
    @crawl = YAML.load_file(CRAWL_PATH)
    @agent = Mechanize.new
    @page = nil
    @courses = Hash.new
  end

  def login
    page = @agent.get LOGIN_URL
    form = page.form

    form.USCID = @account[:username]
    form.PWD = @account[:password]

    page = @agent.submit form
    @page = page

    return self
  end

  def execute_crawl
    base_page = @page
    @crawl.each do |term, depts|
      depts.each do |dept|
        @page = base_page
        select_term term
        select_department dept
      end
    end
  end

  def select_term _x
    puts "Using term #{_x}"
    link = @page.link_with text: /#{_x}/i

    begin
      if link == nil
        raise NoMethodError, "No such term: #{_x}"
      else
        @page = link.click
      end
    rescue => e
      puts "    #{e}"
    end
    return self
  end

  def select_department _x
    puts "  Selecting department #{_x}"

    prompt_link = @page.link_with text: /continue/i
    if prompt_link
      @page = prompt_link.click
    end

    link = @page.link_with text: /#{_x}/i
    subpages = Hash.new

    begin
      if link == nil
        raise NoMethodError, "No such department: #{_x}"
      else 
        @page = link.click

        parse_courses page: @page

        @page.links.each do |link|
          if link.href =~ /&page=(\d+)\z/i
            subpages[$1] = link
          end
        end

        subpages.each do |k, link|
          parse_courses page: link.click
        end
      end
    rescue => e
      puts "    #{e}"     
    end

    return self
  end

  def parse_courses page:
    page.search('.course-title-indent').each do |course_header|
      #ap course_header[:href]
      #ap course_header.at('.crsID').text
      #ap course_header.at('.crsTitl').text

      href = course_header[:href][1..-1]
      # ap href
      course_id = course_header.at('.crsID').text.strip[0..-2]
      course_name = course_header.at('.crsTitl').text

      @courses[course_id] ||= {
        course_name: course_name,
        sections: Hash.new
      }
      
      # ap details.at('.class-details-row').text.gsub(/\s{2,}/, '')
    
      details = page.at('#' + href)
      details.search('.class-details-row').each do |row|
        h_details = Hash.new

        row.search('span').each do |span|
          subtuples = span.text.split(/\:/)
          if subtuples[1] != nil and subtuples[1].strip.length > 0
            rest = subtuples[1..-1].join(':')
            h_details[subtuples[0].downcase.to_sym] = rest.strip
          end
        end

        @courses[course_id][:sections][h_details[:section]] = h_details
      end

      #ap h_details
      #ap '--------'
    end
  end

  def load_to_database
    db_status

    ActiveRecord::Base.transaction do
      @courses.each do |course_code, course_data|
        course = Course.find_or_initialize_by code: course_code
        course.name = course_data[:course_name]
        course.save

        course_data[:sections].each do |section_name, _d|
          section = Section.find_or_initialize_by name: section_name, course_id: course.id
          # section.session = _d[:session]
          section.cs_type = _d[:type]
          section.unit = _d[:units].to_i
          section.registered = parse_registration(_d[:registered], :actual)
          section.limit = parse_registration(_d[:registered], :limit)
          section.location = _d[:location]

          section.save
        end
      end
    end

    db_status
  end

  def monitor course:, section:
    ap course + ': ' + @courses[course][:course_name]
    ap 'Registration: ' + @courses[course][:sections][section][:registered]
  end

private
  def db_status
    ap "Courses: #{Course.count} | Sections: #{Section.count}"
  end

  def parse_registration _raw, _part
    case _raw
    when /closed/i
      return -1
    else
      if _raw =~ /(\d+) of (\d+)/
        case _part
        when :actual
          return $1.to_i
        when :limit
          return $2.to_i
        end
      else
        return -2
      end
    end
  end

end
