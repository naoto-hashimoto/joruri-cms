# encoding: utf-8
require 'builder'
module Article::Controller::Feed
  def render_feed(docs)
    if %w(rss atom).index(params[:format])
      @skip_layout = true
      @site_uri    = Page.site.full_uri
      @node_uri    = @site_uri.gsub(/\/$/, '') + Page.current_node.public_uri
      @req_uri     = @site_uri.gsub(/\/$/, '') + Page.uri
      @feed_name   = "#{Page.title} | #{Page.site.name}"

      data = send("to_#{params[:format]}", docs)
      return render xml: unescape(data)
    end
    false
  end

  def unescape(xml)
    xml = xml.to_s
    # xml = CGI.unescapeHTML(xml)
    # xml = xml.gsub(/&amp;/, '&')
    xml.gsub(/&#(?:(\d*?)|(?:[xX]([0-9a-fA-F]{4})));/) { [Regexp.last_match(1).nil? ? Regexp.last_match(2).to_i(16) : Regexp.last_match(1).to_i].pack('U') }
  end

  def strimwidth(str, size, options = {})
    suffix = options[:suffix] || '..'
    str    = str.sub!(/<[^<>]*>/, '') while /<[^<>]*>/ =~ str
    chars  = str.split(//u)
    chars.size <= size ? str : chars.slice(0, size).join('') + suffix
  end

  def to_rss(docs)
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct!
    xml.rss('version' => '2.0') do
      xml.channel do
        xml.title       @feed_name
        xml.link        @req_uri
        xml.language    'ja'
        xml.description Page.title

        docs.each do |doc|
          xml.item do
            xml.title        doc.title
            xml.link         doc.public_full_uri
            xml.description  strimwidth(doc.body.to_s.gsub(/&nbsp;/, ' '), 500)
            xml.pubDate      doc.published_at.rfc822
            doc.category_items.each do |category|
              xml.category category.title
            end
          end
        end # docs
      end # channel
    end # xml
  end

  def to_atom(docs)
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, version: 1.0, encoding: 'UTF-8'
    xml.feed 'xmlns' => 'http://www.w3.org/2005/Atom' do
      updated = (docs[0] && docs[0].published_at) ? docs[0].published_at : Date.today

      xml.id      "tag:#{Page.site.domain},#{Page.site.created_at.strftime('%Y')}:#{Page.current_node.public_uri}"
      xml.title   @feed_name
      xml.updated updated.strftime('%Y-%m-%dT%H:%M:%S%z').sub(/([0-9][0-9])$/, ':\1')
      xml.link    rel: 'alternate', href: @node_uri
      xml.link    rel: 'self', href: @req_uri, type: 'application/atom+xml', title: @feed_name

      docs.each do |doc|
        xml.entry do
          xml.id      "tag:#{Page.site.domain},#{doc.created_at.strftime('%Y')}:#{doc.public_uri}"
          xml.title   doc.title
          xml.updated doc.published_at.strftime('%Y-%m-%dT%H:%M:%S%z').sub(/([0-9][0-9])$/, ':\1') # .rfc822
          # xml.summary strimwidth(doc.body, 500), :type => 'html'
          xml.summary(type: 'html') do |p|
            p.cdata! strimwidth(doc.body, 500)
          end
          xml.link rel: 'alternate', href: doc.public_full_uri
          # xml.link    :rel => 'enclosure', :href => "#{doc.public_full_uri}#{content.xhtml}", :type => 'text/xhtml'

          if (c = doc.unit) && (node = doc.content.unit_node)
            xml.category term: c.name, scheme: node.public_full_uri, label: "??????/#{c.node_label}"
          end

          if node = doc.content.category_node
            doc.category_items.each do |c|
              xml.category term: c.name, scheme: node.public_full_uri, label: "??????/#{c.node_label}"
            end
          end

          if node = doc.content.attribute_node
            doc.attribute_items.each do |c|
              xml.category term: c.name, scheme: node.public_full_uri, label: "??????/#{c.node_label}"
            end
          end

          if node = doc.content.area_node
            doc.area_items.each do |c|
              xml.category term: c.name, scheme: node.public_full_uri, label: "??????/#{c.node_label}"
            end
          end

          if doc.event_state == 'visible' && doc.event_date && node = doc.content.event_node
            xml.category term: 'event', scheme: node.public_full_uri,
                         label: "????????????/#{doc.event_date.strftime('%Y-%m-%dT%H:%M:%S%z').sub(/([0-9][0-9])$/, ':\1')}"
          end

          xml.author do |auth|
            if doc.inquiry && doc.inquiry.group
              name  = doc.inquiry.group.full_name
              name += "???#{doc.inquiry.charge}" unless doc.inquiry.charge.blank?
              auth.name  name.to_s
              auth.email doc.inquiry.email.to_s
            end
            # auth.uri "#{uri}#{doc.unit.name}/"
          end

          if node = doc.content.tag_node
            doc.tags.each do |c|
              xml.link rel: 'tag', href: "#{node.public_full_uri}#{CGI.escape(c.word)}", type: 'text/xhtml'
            end
          end

          doc.rel_docs.each do |c|
            xml.link rel: 'related', href: c.public_full_uri.to_s, type: 'text/xhtml'
          end
        end # entry
      end # docs
    end # feed
  end
end
