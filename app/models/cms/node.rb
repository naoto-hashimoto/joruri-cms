# encoding: utf-8
class Cms::Node < ActiveRecord::Base
  include Sys::Model::Base
  include Cms::Model::Base::Page
  include Cms::Model::Base::Page::Publisher
  include Cms::Model::Base::Page::TalkTask
  include Cms::Model::Base::Node
  include Sys::Model::Tree
  include Sys::Model::Rel::Unid
  include Sys::Model::Rel::UnidRelation
  include Sys::Model::Rel::Creator
  include Cms::Model::Rel::NodeSetting
  include Cms::Model::Rel::Site
  include Cms::Model::Rel::Concept
  include Cms::Model::Rel::Content
  include Cms::Model::Auth::Concept

  include StateText

  belongs_to :parent, foreign_key: :parent_id, class_name: 'Cms::Node'
  belongs_to :layout, foreign_key: :layout_id, class_name: 'Cms::Layout'

  has_many   :children, -> { order(:name) }, foreign_key: :parent_id,
             class_name: 'Cms::Node', dependent: :destroy


 validates :concept_id, presence: true, if: %(parent_id == 0)
 validates :parent_id, :state, :model, :name, :title, presence: true
 validates :name, presence: true,
           uniqueness: { scope: [:site_id, :parent_id], if: %(!replace_page?) },
           format: { with: /\A[0-9A-Za-z@\.\-_\+\s]+\z/,
                     message: :not_a_filename, if: %(parent_id != 0) }

  after_destroy :remove_file

  scope :search, ->(params) {
    rel = all

    params.each do |n, v|
      next if v.to_s == ''

      case n
      when 's_state'
        rel = rel.where(state: v)
      when 's_title'
        rel = rel.where(arel_table[:title].matches("%#{v}%"))
      when 's_body'
        rel = rel.where(arel_table[:body].matches("%#{v}%"))
      when 's_directory'
        rel = rel.where(directory: v)
      when 's_name_or_title'
        rel = rel.where(arel_table[:name].matches("%#{v}%")
                        .or(arel_table[:title].matches("%#{v}%")))
      when 's_keyword'
        rel = rel.where(
          arel_table[:title].matches("%#{v}%")
          .or(arel_table[:body].matches("%#{v}%"))
          .or(arel_table[:mobile_title,].matches("%#{v}%"))
          .or(arel_table[:mobile_body].matches("%#{v}%"))
          .or(arel_table[:title].matches("%#{v}%"))
        )
      end
    end if params.size != 0

    rel
  }

  def validate
    errors.add :parent_id, :invalid if !id.nil? && id == parent_id
    errors.add :route_id, :invalid if !id.nil? && id == route_id
  end

  def states
    [%w(???????????? public), %w(??????????????? closed)]
  end

  def tree_title(opts = {})
    level_no = ancestors.size
    opts.reverse_merge!(prefix: '??????', depth: 0)
    opts[:prefix] * [level_no - 1 + opts[:depth], 0].max + title
  end

  def self.find_by_uri(path, site_id)
    return nil if path.to_s == ''

    item = where(site_id: site_id, parent_id: 0, name: '/').order(:id).first
    unless item
      return nil
    end
    return item if path == '/'

    path.split('/').each do |p|
      next if p == ''

      item = where(site_id: site_id, parent_id: item.id, name: p)
             .order(:id).first
      unless item
        return nil
      end
    end
    item
  end

  def public_path
    "#{site.public_path}#{public_uri}".gsub(/\?.*/, '')
  end

  attr_writer :public_uri

  def public_uri
    return @public_uri if @public_uri
    uri = site.uri
    parents_tree.each { |n| uri += "#{n.name}/" if n.name != '/' }
    uri = uri.gsub(/\/$/, '') if directory == 0
    @public_uri = uri
  end

  def public_full_uri
    return @public_full_uri if @public_full_uri
    uri = site.full_uri
    parents_tree.each { |n| uri += "#{n.name}/" if n.name != '/' }
    uri = uri.gsub(/\/$/, '') if directory == 0
    @public_full_uri = uri
  end

  def inherited_concept(key = nil)
    unless @_inherited_concept
      concept_id = concept_id

      parents_tree.each do |r|
        concept_id = r.concept_id if r.concept_id
      end unless concept_id

      return nil unless concept_id

      @_inherited_concept = Cms::Concept.find_by(id: concept_id)
      return nil unless @_inherited_concept
    end

    key.nil? ? @_inherited_concept : @_inherited_concept.send(key)
  end

  def inherited_layout
    layout_id = layout_id

    parents_tree.each do |r|
      layout_id = r.layout_id if r.layout_id
    end unless layout_id

    Cms::Layout.find_by(id: layout_id)
  end

  def all_nodes_with_level
    search = lambda do |current, level|
      _nodes = { level: level, item: current, children: nil }
      return _nodes if level >= 10
      return _nodes if current.children.empty?

      _tmp = []
      current.children.each do |child|
        next unless _c = search.call(child, level + 1)
        _tmp << _c
      end
      _nodes[:children] = _tmp

      return _nodes
    end

    search.call(self, 0)
  end

  def all_nodes_collection(options = {})
    collection = lambda do |current, level|
      title = ''

      if level > 0
        (level - 0).times { |_i| title += options[:indent] || '  ' }
        title += options[:child] || ' ' if level > 0
      end

      title += current[:item].title
      list = [[title, current[:item].id]]
      return list unless current[:children]

      current[:children].each do |child|
        list += collection.call(child, level + 1)
      end

      return list
    end

    collection.call(all_nodes_with_level, 0)
  end

  def css_id
    ''
  end

  def css_class
    'content content' + controller.singularize.camelize
  end

  def candidate_parents
    nodes = Core.site.root_node.descendants do |child|
      rel = child.where(directory: 1)
      rel = rel.where.not(id: id) if new_record?
      rel
    end
    nodes.map{|n| [n.tree_title, n.id]}
  end

  def candidate_routes
    nodes = Core.site.root_node.descendants do |child|
      rel = child.where(directory: 1)
      rel = rel.where.not(id: id) if new_record?
      rel
    end
    nodes.map{|n| [n.tree_title, n.id]}
  end

  def locale(name)
    model = self.class.to_s.underscore
    label = ''
    if model != 'cms/node'
      label = I18n.t name, scope: [:activerecord, :attributes, model]
      return label if label !~ /^translation missing:/
    end
    label = I18n.t name, scope: [:activerecord, :attributes, 'cms/node']
    label =~ /^translation missing:/ ? name.to_s.humanize : label
  end

  # group chenge
  def information
    "[??????????????????????????????]\n#{public_uri}"
  end

  protected

  def remove_file
    close_page # rescue nil
    true
  end

  class Directory < Cms::Node
    def close_page(_options = {})
      true
    end
  end

  class Sitemap < Cms::Node
  end

  class Page < Cms::Node
    include Sys::Model::Rel::Recognition
    include Cms::Model::Rel::Inquiry
    include Sys::Model::Rel::Task

    validate :validate_inquiry,
             if: %(state == 'public')
    validate :validate_recognizers,
             if: %(state == "recognize")

    def unid_model_name
      'Cms::Node'
    end

    def states
      s = [%w(??????????????? draft), %w(???????????? recognize)]
      s << %w(???????????? public) if Core.user.has_auth?(:manager)
      s
    end

    def publish(content, _options = {})
      @save_mode = :publish
      self.state = 'public'
      self.published_at ||= Core.now
      return false unless save(validate: false)

      if rep = replaced_page
        rep.destroy if rep.directory == 0
      end

      publish_page(content, path: public_path, uri: public_uri)
    end

    def close
      @save_mode = :close
      self.state = 'closed' if state == 'public'
      # self.published_at = nil
      return false unless save(validate: false)
      close_page
      true
    end

    def duplicate(rel_type = nil)
      item = self.class.new(attributes)
      item.id            = nil
      item.unid          = nil
      item.created_at    = nil
      item.updated_at    = nil
      item.recognized_at = nil
      # item.published_at  = nil
      item.state         = 'draft'

      if rel_type.nil?
        item.name          = nil
        item.title         = item.title.gsub(/^(????????????)*/, "????????????")
      end

      item.in_recognizer_ids = recognition.recognizer_ids if recognition

      item.in_inquiry = if !inquiry.nil? && inquiry.group_id == Core.user.group_id
                          inquiry.attributes
                        else
                          { group_id: Core.user.group_id }
                        end

      return false unless item.save(validate: false)

      # node_settings
      settings.each do |setting|
        dupe_setting = Cms::NodeSetting.new(setting.attributes)
        dupe_setting.id = nil
        dupe_setting.node_id = item.id
        dupe_setting.created_at = nil
        dupe_setting.updated_at = nil
        dupe_setting.save(validate: false)
      end

      if rel_type == :replace
        rel = Sys::UnidRelation.new
        rel.unid     = item.unid
        rel.rel_unid = unid
        rel.rel_type = 'replace'
        rel.save
      end

      item
    end
  end
end
