class VectorsearchTools::BrowserWebTool
  extend Langchain::ToolDefinition

  define_function :fetch_url, description: "Fetch the content of an URL" do
    property :url, type: "string", description: "The URL to fetch", required: true
  end

  # Fetch the content of an URL using the REST client gem with a timeout of 5 seconds
  def fetch_url(url:)
    response = RestClient::Request.execute(method: :get, url: url, timeout: 5)
    cleaned_response = cleanup_html(response.body)

    cleaned_response
  rescue RestClient::ExceptionWithResponse => e
    "ERROR FETCHING URL: #{e.response.code}"
  rescue RestClient::Exception => e
    "ERROR FETCHING URL"
  rescue StandardError => e
    "ERROR FETCHING URL"
  end

  private

  def cleanup_html(html)
    # Parse the HTML
    doc = Nokogiri::HTML(html)

    # Remove unwanted tags completely
    unwanted_tags = %w[style script link meta noscript iframe object embed svg]
    unwanted_tags.each do |tag|
      doc.css(tag).remove
    end

    # Remove all attributes from remaining tags
    doc.traverse do |node|
      if node.element?
        # Remove all attributes
        node.attributes.each { |attr, _| node.remove_attribute(attr) }
      end
    end

    # Remove all comments
    doc.xpath("//comment()").remove

    # Remove all empty tags
    doc.css("*").each do |node|
      node.remove if node.inner_text.strip.empty?
    end

    # Get only the body content
    body = doc.at_css("body")

    # Return the cleaned HTML
    data = body ? body.inner_html : doc.to_html

    # Remove all newlines and extra spaces
    data = data.gsub!(/\n/, "").gsub!(/\s+/, " ")

    data
  end
end
