require File.expand_path('../../test_helper', __FILE__)

class Klass
  def initialize(str)
    @str = str
  end
  def hello
    @str
  end
end

module SpockMarshalStrategy
  extend self

  def marshal_type
    :text
  end

  def to_sym
    :spock
  end

  # Change days to hours
  def marshal(i)
    (i.to_i * 24).to_s
  end

  # Change hours to days
  def unmarshal(str)
    str.to_i / 24
  end

  Qwirk::MarshalStrategy.register(self)
end

describe Qwirk::MarshalStrategy, 'test the various marshaling strategies and the homegrown spock one' do
  before do
    @bson   = Qwirk::MarshalStrategy.find(:bson)
    @json   = Qwirk::MarshalStrategy.find(:json)
    @none   = Qwirk::MarshalStrategy.find(:none)
    @ruby   = Qwirk::MarshalStrategy.find(:ruby)
    @string = Qwirk::MarshalStrategy.find(:string)
    @yaml   = Qwirk::MarshalStrategy.find(:yaml)
    @spock  = Qwirk::MarshalStrategy.find(:spock)
  end

  it 'should marshal and unmarshal correctly' do
    hash = {'foo' => 42, 'bar' => 'zulu'}
    str  = 'abcdef1234'
    obj  = Klass.new('hello')
    i    = 6
    @bson.unmarshal(@bson.marshal(hash)).must_equal hash
    @json.unmarshal(@json.marshal(hash)).must_equal hash
    @none.unmarshal(@none.marshal(hash)).must_equal hash
    @ruby.unmarshal(@ruby.marshal(hash)).must_equal hash
    @yaml.unmarshal(@yaml.marshal(hash)).must_equal hash
    @string.unmarshal(@string.marshal(str)).must_equal str
    @ruby.unmarshal(@ruby.marshal(obj)).hello.must_equal obj.hello
    @spock.unmarshal(@spock.marshal(i)).must_equal i
  end
end
