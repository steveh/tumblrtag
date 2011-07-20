require "sinatra/base"
require "nokogiri"
require "active_support/core_ext/object/try"
require "active_support/time"
require "hpricot"
require "excon"

class TumblrTag < Sinatra::Base

  get "/:tag" do
    tag = params[:tag].gsub(/[^a-z0-9]/, "")

    connection = Excon.new("http://www.tumblr.com/")

    featured = connection.request(:method => "GET", :path => "/tagged/#{tag}").body
    popular  = connection.request(:method => "GET", :path => "/tagged/#{tag}/popular").body

    pages = [featured, popular]

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.rss :version => "2.0" do
        xml.channel do
          xml.title "Tumblr tag - #{tag}"
          xml.description "Tumblr posts tagged with #{tag}"
          xml.link "http://www.tumblr.com/tagged/#{tag}/"

          pages.each do |page|
            html = Hpricot(page)

            html.search("ol#posts li").each do |hp|
              permalink = hp.search("a.permalink").first
              content = hp.search("div.post_content")

              content.search("img").each do |hi|
                hi.attributes["onclick"] = ""
                hi.attributes["onload"] = ""
                hi.attributes["width"] = ""
                hi.attributes["height"] = ""
                hi.attributes["src"] = hi.attributes["src"].gsub(/tumblr\_([a-z0-9\_]+)\_100/i, "tumblr_\\1_500")
              end

              content.search("script").remove

              xml.item do
                xml.title       hp.search("div.post_title").first.try(:inner_html)
                xml.description content.first.try(:inner_html)
                xml.pubDate     Time.now.to_s(:rfc822)
                xml.link        permalink ? permalink.attributes["href"] : nil
                xml.author      hp.search("div.post_info a").first.try(:inner_html)
              end
            end
          end
        end
      end
    end

    builder.to_xml
  end

end
