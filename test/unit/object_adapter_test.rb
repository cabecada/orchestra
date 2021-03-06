class ObjectAdapterTest < Minitest::Test
  def setup
    @builder = Orchestra::DSL::Operations::Builder.new
  end

  def test_method_does_not_exist_on_singleton
    error = assert_raises NotImplementedError do
      @builder.add_step Splitter, :provides => :words, :method => :foo
    end

    assert_equal "ObjectAdapterTest::Splitter does not implement method `foo'", error.message
  end

  def test_method_does_not_exist_on_object
    error = assert_raises NotImplementedError do
      @builder.add_step Upcaser, :provides => :words
    end

    assert_equal "ObjectAdapterTest::Upcaser does not implement instance method `execute'", error.message
  end

  def test_dependencies_inferred_from_method_defaults
    step = @builder.add_step Upcaser, :iterates_over => :words, :provides => :upcased_words, :method => :call

    assert_equal [:words, :transform], step.dependencies
    assert_equal [:words], step.required_dependencies
  end

  def test_executing_an_operation_with_integrated_objects
    operation = integrated_objects_operation

    result = Orchestra.execute(
      operation,
      :sentence  => "the quick brown fox jumps over the lazy dog",
      :bold_text => "*",
    )

    assert_equal(
      %(*THE* *QUICK* *BROWN* *FOX* *JUMPS* *OVER* *THE* *LAZY* *DOG*),
      result,
    )
  end

  def test_provent_singleton_objects_from_handling_collections
    error = assert_raises ArgumentError do
      Orchestra::Operation.new do
        step Splitter, :iterates_over => :sentence
      end
    end

    assert_equal(
      "ObjectAdapterTest::Splitter is a singleton; cannot iterate over collection :sentence",
      error.message
    )
  end

  def test_name_includes_method_when_not_using_execute
    assert_equal(
      %i(
        object_adapter_test/splitter
        object_adapter_test/upcaser#call
        object_adapter_test/bolder#call
        object_adapter_test/joiner#join
      ),
      integrated_objects_operation.steps.keys,
    )
  end

  private

  def integrated_objects_operation
    Orchestra::Operation.new do
      step Splitter, :provides => :words
      step Upcaser, :iterates_over => :words, :provides => :upcased_words, :method => :call
      step Bolder, :iterates_over => :upcased_words, :provides => :bolded_words, :method => :call
      result Joiner, :method => :join
    end
  end

  module Splitter
    extend self

    def execute sentence
      sentence.split %r{[[:space:]]+}
    end
    alias_method :call, :execute
  end

  class Upcaser
    def initialize transform = :upcase
      @transform = transform
    end

    def call element
      element.public_send @transform
    end
  end

  class Bolder
    attr :bold_text

    def initialize bold_text = "**"
      @bold_text = bold_text
    end

    def call word
      "#{bold_text}#{word}#{bold_text}"
    end
  end

  class Joiner
    def initialize bolded_words
      @bolded_words = bolded_words
    end

    def join
      @bolded_words.join ' '
    end
  end
end
