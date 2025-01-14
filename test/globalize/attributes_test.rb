# encoding: utf-8
require File.expand_path('../../test_helper', __FILE__)

class AttributesTest < Minitest::Spec

  describe 'translated attribute reader' do
    it 'is defined for translated attributes' do
      assert Post.new.respond_to?(:title)
    end

    it 'Post#columns does not include translated attributes' do
      assert (Post.column_names.map(&:to_sym) & Post.translated_attribute_names.map(&:to_sym)).empty?
    end

    it 'returns the correct translation for a saved record after locale switching' do
      post = Post.create(:title => 'title', published: false)
      post.update(:title => 'Titel', :locale => :de, published: true)
      post.reload

      assert_translated post, :en, :title, 'title'
      assert_translated post, :de, :title, 'Titel'

      assert_translated post, :en, :published, false
      assert_translated post, :de, :published, true
    end

    # TODO: maybe move this somewhere else?
    it 'does not create empty translations when loaded or saved in a new locale' do
      post = Post.create(:title => 'title')
      assert_equal 1, post.translations.length
      I18n.locale = :de

      post.reload
      assert_equal 1, post.translations.length

      post.save
      assert_equal 1, post.reload.translations.length
    end

    it 'returns the correct translation for an unsaved record after locale switching' do
      post = Post.create(:title => 'title')
      with_locale(:de) { post.title = 'Titel' }

      assert_translated post, :en, :title, 'title'
      assert_translated post, :de, :title, 'Titel'
    end

    it 'returns correct translation for both saved/unsaved records while switching locales' do
      post = Post.new(:title => 'title')
      with_locale(:de) { post.title = 'Titel' }
      with_locale(:he) { post.title = 'שם' }

      assert_translated post, :de, :title, 'Titel'
      assert_translated post, :he, :title, 'שם'
      assert_translated post, :en, :title, 'title'
      assert_translated post, :he, :title, 'שם'
      assert_translated post, :de, :title, 'Titel'

      post.save
      post.reload

      assert_translated post, :de, :title, 'Titel'
      assert_translated post, :he, :title, 'שם'
      assert_translated post, :en, :title, 'title'
      assert_translated post, :he, :title, 'שם'
      assert_translated post, :de, :title, 'Titel'
    end

    it 'returns nil if no translations are found on an unsaved record' do
      post = Post.new(:title => 'foo')
      assert_equal 'foo', post.title
      assert_nil post.content
    end

    it 'returns nil if no translations are found on a saved record' do
      post = Post.create(:title => 'foo')
      post.reload
      assert_equal 'foo', post.title
      assert_nil post.content
    end

    it 'will use the current locale on Globalize or I18n if not passed any arguments' do
      with_locale(:de) do
        Post.create!(:title => 'Titel', :content => 'Inhalt')
      end
      I18n.locale = :de
      assert_equal 'Titel', Post.first.title

      I18n.locale = :en
      Globalize.locale = :de
      assert_equal 'Titel', Post.first.title
    end

    it 'will use the given locale when passed a locale' do
      post = with_locale(:de) do
        Post.create!(:title => 'Titel', :content => 'Inhalt')
      end
      assert_equal 'Titel', post.title(:de)
    end
  end

  describe 'translated attribute writer' do
    it 'is defined for translated attributes' do
      assert Post.new.respond_to?(:title=)
    end

    it 'returns its argument' do
      assert_equal 'foo', Post.new.title = 'foo'
    end

    it 'only triggers save on translations once parent model is saved' do
      post = Post.new
      assert post.translations.all?(&:new_record?)

      post.title = 'something'
      assert post.translations.all?(&:new_record?)

      post.save
      assert post.translations.all?(&:persisted?)
      assert_equal 1, post.translations.length
    end

    it 'does not change untranslated value' do
      post = Post.create(:title => 'title')
      assert_nil post.untranslated_attributes['title']
      post.title = 'changed title'
      assert_nil post.untranslated_attributes['title']
    end

    it 'does not remove secondary unsaved translations' do
      post = with_locale(:en) do
        post = Post.new(:translations_attributes => {
          "0" => { :locale => 'en', :title => 'title' },
          "1" => { :locale => 'it', :title => 'titolo' }
        })
        post.title = 'changed my mind'
        post
      end
      post.save!
      saved_locales = post.translations.map(&:locale)
      assert saved_locales.include? :it
    end

    it 'translates the reference' do
      media = Media.create!
      post = Post.create!(title: 'title', media: media)
      assert_equal media.id, post.media_id
    end
  end

  describe '#attribute_names' do
    it 'returns translated and regular attribute names' do
      assert_equal %w(blog_id content title), Post.new.attribute_names.sort & %w(blog_id content title)
    end
  end

  describe '#attributes' do
    it 'returns translated and regular attributes' do
      post = Post.create(:title => 'foo')
      attributes = post.attributes.slice('id', 'blog_id', 'title', 'content')
      assert_equal({ 'id' => post.id, 'blog_id' => nil, 'title' => 'foo', 'content' => nil }, attributes)
    end
  end

  describe '#attributes=' do
    it 'assigns translated attributes' do
      post = Post.create(:title => 'title')
      post.attributes = { :title => 'newtitle' }
      assert_equal post.title, 'newtitle'
      with_locale(:de) do
        post.attributes = { :title => 'title in de' }
        assert_equal post.title, 'title in de'
      end
      assert_equal post.title, 'newtitle'
    end

    it 'raises ArgumentError if attributes is blank' do
      post = Post.create(:title => 'title')
      assert_raises(ArgumentError) { post.attributes = nil }
      assert_raises(ArgumentError) { post.attributes = [] }
    end

    it 'does not modify arguments passed in' do
      post = Post.create(:title => 'title')
      params = {'id' => 1, 'title' => 'newtitle', 'locale' => 'de'}
      post.attributes = params
      assert_equal params, {'id' => 1, 'title' => 'newtitle', 'locale' => 'de'}
      with_locale(:de) { assert_equal post.title, 'newtitle' }
    end
  end

  describe '#assign_attributes' do
    it 'assigns translated attributes' do
      post = Post.create(:title => 'title')
      post.assign_attributes(:title => 'newtitle')
      assert_equal post.title, 'newtitle'
      with_locale(:de) do
        post.assign_attributes(:title => 'title in de')
        assert_equal post.title, 'title in de'
      end
      assert_equal post.title, 'newtitle'
    end

    it 'raises ArgumentError if attributes is blank' do
      post = Post.create(:title => 'title')
      assert_raises(ArgumentError) { post.assign_attributes(nil) }
      assert_raises(ArgumentError) { post.assign_attributes([]) }
    end

    it 'does not modify arguments passed in' do
      post = Post.create(:title => 'title')
      params = {'id' => 1, 'title' => 'newtitle', 'locale' => 'de'}
      post.assign_attributes(params)
      assert_equal params, {'id' => 1, 'title' => 'newtitle', 'locale' => 'de'}
      with_locale(:de) { assert_equal post.title, 'newtitle' }
    end
  end

  describe '#write_attribute' do
    it 'returns the value for non-translated attributes' do
      user = User.create(:name => 'Max Mustermann', :email => 'max@mustermann.de')
      new_email = 'm.muster@mann.de'
      assert_equal new_email, user.write_attribute('email', new_email)
    end
  end

  describe '#translated_attribute_names' do
    it 'returns translated attribute names' do
      assert_equal [:title, :content], Post.translated_attribute_names & [:title, :content]
    end
  end

  describe '#<attr>_before_type_cast' do
    it 'works for translated attributes' do
      post = Post.create(:title => 'title')
      post.update(:title => "Titel", :locale => :de)

      with_locale(:en) { assert_equal 'title', post.title_before_type_cast }
      with_locale(:de) { assert_equal 'Titel', post.title_before_type_cast }
    end
  end

  describe 'STI model' do
    it 'saves all translations after locale switching' do
      child = Child.new(:content => 'foo')
      with_locale(:de) { child.content = 'bar' }
      with_locale(:he) { child.content = 'baz' }
      child.save
      child.reload

      assert_translated child, :en, :content, 'foo'
      assert_translated child, :de, :content, 'bar'
      assert_translated child, :he, :content, 'baz'
    end
  end

  describe 'serializable attribute' do
    it 'keeps track of serialized attributes between classes' do
      assert_equal UnserializedAttr.globalize_serialized_attributes, {}

      if Globalize.rails_7_2?
        assert_equal SerializedAttr.globalize_serialized_attributes, {:meta=>{}}
        assert_equal ArraySerializedAttr.globalize_serialized_attributes, {:meta=>{:type=>Array}}
        assert_equal JSONSerializedAttr.globalize_serialized_attributes, {:meta=>{:coder=>JSON}}
      elsif Globalize.rails_7_1?
        assert_equal SerializedAttr.globalize_serialized_attributes, {:meta=>{}}
        assert_equal ArraySerializedAttr.globalize_serialized_attributes, {:meta=>[Array, {}]}
        assert_equal JSONSerializedAttr.globalize_serialized_attributes, {:meta=>[JSON, {}]}
      else
        assert_equal SerializedAttr.globalize_serialized_attributes[:meta].class, ActiveRecord::Coders::YAMLColumn
        assert_equal ArraySerializedAttr.globalize_serialized_attributes[:meta].class, ActiveRecord::Coders::YAMLColumn
        assert_equal JSONSerializedAttr.globalize_serialized_attributes[:meta], ActiveRecord::Coders::JSON
      end
    end

    it 'works with default marshalling, without data' do
      model = SerializedAttr.create
      assert_nil model.meta
    end

    it 'works with default marshalling, with data' do
      data = {:foo => "bar", :whats => "up"}
      model = SerializedAttr.create(:meta => data)
      assert_equal data, model.meta
    end

    it 'works with Hash marshalling, without data' do
      model = SerializedHash.new
      assert_equal Hash.new, model.meta
    end

    it 'works with Array marshalling, without data' do
      model = ArraySerializedAttr.new
      assert_equal Array.new, model.meta
    end
  end

  describe '#column_for_attribute' do
    it 'delegates to translations adapter' do
      post = Post.new
      assert_equal post.globalize.send(:column_for_attribute, :title), post.column_for_attribute(:title)
    end
  end

  if Globalize::Test::Database.native_array_support?
    describe 'columns with default array value' do
      it 'returns the typecasted default value for arrays with empty array as default' do
        product = Product.new
        assert_equal [], product.array_values
      end
    end
  end

  describe 'translation table with null:false fields without default value ' do
    DB_EXCEPTIONS = %w(
      SQLite3::ConstraintException
      PG::NotNullViolation
      Mysql2::Error
      ActiveRecord::JDBCError
    )

    it 'does not save a record with an empty required field' do
      err = assert_raises ActiveRecord::StatementInvalid do
        Artwork.create
      end

      assert_match(/#{DB_EXCEPTIONS.join('|')}/, err.message)
    end

    it 'saves a record with a filled required field' do
      artwork = Artwork.new
      artwork.title = "foo"
      artwork.save!
      artwork.reload

      assert_equal 1, artwork.translations.length
      assert_equal 'foo', artwork.title
    end

    it 'does not save a record with an empty required field using nested attributes' do
      err = assert_raises ActiveRecord::StatementInvalid do
        Artwork.create(:translations_attributes => {
          "0" => { :locale => 'en', :title => 'title' },
          "1" => { :locale => 'it' }
        })
      end

      assert_match(/#{DB_EXCEPTIONS.join('|')}/, err.message)
    end

    it 'saves a record with a filled required field using nested attributes' do
      artwork = Artwork.new(:translations_attributes => {
        "0" => { :locale => 'en', :title => 'title' },
        "1" => { :locale => 'it', :title => 'titolo' }
      })
      artwork.save!
      artwork.reload

      assert_equal 2, artwork.translations.length
      assert_equal 'title', artwork.title
      assert_equal 'titolo', artwork.title(:it)
    end
  end
end
