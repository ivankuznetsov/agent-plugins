# frozen_string_literal: true

require_relative 'test_helper'

class HelpersTest < Minitest::Test
  # TextUtils Tests
  def test_extract_sentences_basic
    text = 'This is sentence one. This is sentence two. And here is the third!'
    sentences = AgentSeo::Helpers::TextUtils.extract_sentences(text)

    assert_equal 3, sentences.length
    assert_equal 'This is sentence one', sentences[0]
    assert_equal 'This is sentence two', sentences[1]
    assert_equal 'And here is the third', sentences[2]
  end

  def test_extract_sentences_with_question_marks
    text = 'What is this? I am not sure. Are you sure!'
    sentences = AgentSeo::Helpers::TextUtils.extract_sentences(text)

    assert_equal 3, sentences.length
    assert_equal 'What is this', sentences[0]
    assert_equal 'I am not sure', sentences[1]
    assert_equal 'Are you sure', sentences[2]
  end

  def test_extract_sentences_empty_string
    sentences = AgentSeo::Helpers::TextUtils.extract_sentences('')
    assert_empty sentences
  end

  def test_extract_sentences_removes_empty_entries
    text = 'One sentence... Another one!'
    sentences = AgentSeo::Helpers::TextUtils.extract_sentences(text)

    assert_equal 2, sentences.length
    assert sentences.none?(&:empty?)
  end

  def test_word_count_basic
    text = 'This is a simple sentence with eight words'
    count = AgentSeo::Helpers::TextUtils.word_count(text)
    assert_equal 8, count
  end

  def test_word_count_empty
    count = AgentSeo::Helpers::TextUtils.word_count('')
    assert_equal 0, count
  end

  # MarkdownParser Tests
  def test_extract_headers_h1
    content = "# Main Title\n\nSome content here."
    headers = AgentSeo::Helpers::MarkdownParser.extract_headers(content)

    assert_equal 1, headers.length
    assert_equal 1, headers[0].level
    assert_equal 'Main Title', headers[0].text
    assert_equal 0, headers[0].line_number
  end

  def test_extract_headers_multiple_levels
    content = <<~MARKDOWN
      # H1 Title

      Some intro text.

      ## H2 Section One

      Content for section one.

      ### H3 Subsection

      More details.

      ## H2 Section Two

      Another section.
    MARKDOWN

    headers = AgentSeo::Helpers::MarkdownParser.extract_headers(content)

    assert_equal 4, headers.length

    assert_equal 1, headers[0].level
    assert_equal 'H1 Title', headers[0].text
    assert_equal 0, headers[0].line_number

    assert_equal 2, headers[1].level
    assert_equal 'H2 Section One', headers[1].text

    assert_equal 3, headers[2].level
    assert_equal 'H3 Subsection', headers[2].text

    assert_equal 2, headers[3].level
    assert_equal 'H2 Section Two', headers[3].text
  end

  def test_extract_headers_strips_whitespace
    content = "# Title with trailing space   \n\n## Another title  "
    headers = AgentSeo::Helpers::MarkdownParser.extract_headers(content)

    assert_equal 2, headers.length
    assert_equal 'Title with trailing space', headers[0].text
    assert_equal 'Another title', headers[1].text
  end

  def test_extract_headers_empty_content
    headers = AgentSeo::Helpers::MarkdownParser.extract_headers('')
    assert_empty headers
  end

  def test_extract_headers_no_headers
    content = "Just some regular text.\n\nMore text here."
    headers = AgentSeo::Helpers::MarkdownParser.extract_headers(content)
    assert_empty headers
  end

  def test_extract_headers_ignores_inline_hash
    content = "This has a #hashtag but no header.\n\n# Real Header"
    headers = AgentSeo::Helpers::MarkdownParser.extract_headers(content)

    assert_equal 1, headers.length
    assert_equal 'Real Header', headers[0].text
  end

  # Scoring Tests
  def test_letter_grade_excellent
    assert_equal 'A (Excellent)', AgentSeo::Helpers::Scoring.letter_grade(95)
    assert_equal 'A (Excellent)', AgentSeo::Helpers::Scoring.letter_grade(90)
    assert_equal 'A (Excellent)', AgentSeo::Helpers::Scoring.letter_grade(100)
  end

  def test_letter_grade_good
    assert_equal 'B (Good)', AgentSeo::Helpers::Scoring.letter_grade(85)
    assert_equal 'B (Good)', AgentSeo::Helpers::Scoring.letter_grade(80)
    assert_equal 'B (Good)', AgentSeo::Helpers::Scoring.letter_grade(89)
  end

  def test_letter_grade_average
    assert_equal 'C (Average)', AgentSeo::Helpers::Scoring.letter_grade(75)
    assert_equal 'C (Average)', AgentSeo::Helpers::Scoring.letter_grade(70)
    assert_equal 'C (Average)', AgentSeo::Helpers::Scoring.letter_grade(79)
  end

  def test_letter_grade_needs_work
    assert_equal 'D (Needs Work)', AgentSeo::Helpers::Scoring.letter_grade(65)
    assert_equal 'D (Needs Work)', AgentSeo::Helpers::Scoring.letter_grade(60)
    assert_equal 'D (Needs Work)', AgentSeo::Helpers::Scoring.letter_grade(69)
  end

  def test_letter_grade_poor
    assert_equal 'F (Poor)', AgentSeo::Helpers::Scoring.letter_grade(55)
    assert_equal 'F (Poor)', AgentSeo::Helpers::Scoring.letter_grade(0)
    assert_equal 'F (Poor)', AgentSeo::Helpers::Scoring.letter_grade(59)
  end

  def test_letter_grade_edge_cases
    # Negative scores fall through to 'F (Poor)'
    assert_equal 'F (Poor)', AgentSeo::Helpers::Scoring.letter_grade(-10)
    # Scores > 100 fall through to 'F (Poor)' since they don't match any range
    # (The 90..100 range is inclusive, so 150 is outside it)
    assert_equal 'F (Poor)', AgentSeo::Helpers::Scoring.letter_grade(150)
  end
end
