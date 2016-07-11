class Mech
  MASTER_ACCOUNT_PATH = Rails.root.join('config', 'master_account.yml').to_s
  CRAWL_PATH = Rails.root.join('config', 'crawl_path.yml').to_s
  LOGIN_URL = 'https://webreg.usc.edu'

  attr_reader :account, :crawl, :page

  def initialize
    @account = YAML.load_file(MASTER_ACCOUNT_PATH).symbolize_keys
    @crawl = YAML.load_file(CRAWL_PATH)
    @agent = Mechanize.new
    @page = nil
    @current_term = nil
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

    return self
  end

  def list_terms
    ap @page.links.select{ |x| x.text =~ /\d+ classes/i }.collect{ |x| x.text }
  end

  def list_departments
    depts = Hash.new
    @page.links.select{ |x| x.href =~ /\/courses\?deptid\=/i }.each do |link|
      link.href =~ /deptid=(\w+)/i
      depts[$1.downcase.to_sym] = link.text
    end

    ap Hash[depts.sort]
  end

  def list_courses
    courses = Hash.new

    @courses.values.first.each do |code, data|
      courses[code] = data[:course_name]
    end

    ap Hash[courses.sort]
  end

  def select_term _x
    puts "Using term #{_x}"
    link = @page.link_with text: /#{_x}/i

    begin
      if link == nil
        raise NoMethodError, "No such term: #{_x}"
      else
        @current_term = _x
        @courses[@current_term] ||= Hash.new
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

    # link = @page.link_with text: /#{_x}/i
    link = @page.link_with href: /#{_x}$/i
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

      @courses[@current_term][course_id] ||= {
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

        @courses[@current_term][course_id][:sections][h_details[:section]] = h_details
      end
    end
  end

  def load_to_database
    db_status

    ActiveRecord::Base.transaction do
      @courses.each do |term_name, term_data|
        term = Term.find_or_initialize_by name: term_name
        term.save

        term_data.each do |course_code, course_data|
          course = Course.find_or_initialize_by code: course_code, term_id: term.id
          course.name = course_data[:course_name]
          course.save

          #ap "Section countscourse_data.count
          course_data[:sections].each do |section_name, _d|
            section = Section.find_or_initialize_by name: section_name, course_id: course.id
            # section.session = _d[:session]
            section.cs_type = _d[:type]
            section.unit = _d[:units].to_i
            section.registered, section.limit = parse_registration _d[:registered]
            section.time = _d[:time]
            section.days = _d[:days]
            section.location = _d[:location]

            section.save
          end
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

  def parse_registration _raw
    case _raw
    when /closed/i
      return [-1, -1]
    else
      if _raw =~ /(\d+)[^\d]+(\d+)/i
        return [$1.to_i, $2.to_i]
      else
        return [-2, -2]
      end
    end
  end

end
