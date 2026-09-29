require "httparty"
require "json"
require "logger"

module LLM
  class AnthropicClient < Client
    API_URL = "https://api.anthropic.com/v1/messages"
    
    def initialize(api_key: ENV["ANTHROPIC_API_KEY"], model: ENV.fetch("ANTHROPIC_MODEL", "claude-3-5-sonnet-20241022"))
      @api_key = api_key
      @model = model
      @logger = Logger.new(STDOUT)
    end

    def complete(system:, messages:, schema: nil, tools: nil)
      body = {
        model: @model,
        max_tokens: 4096,
        system: system,
        messages: messages
      }

      if schema
        body[:tools] = [{
          name: "structured_output",
          description: "Return structured output matching the provided schema",
          input_schema: schema
        }]
        body[:tool_choice] = { type: "tool", name: "structured_output" }
      elsif tools
        body[:tools] = tools
      end

      response = HTTParty.post(
        API_URL,
        headers: {
          "Content-Type" => "application/json",
          "x-api-key" => @api_key,
          "anthropic-version" => "2023-06-01"
        },
        body: body.to_json
      )

      unless response.success?
        @logger.error("Anthropic API error: #{response.code} - #{response.body}")
        raise LLMError, "API error: #{response.code}"
      end

      data = JSON.parse(response.body)
      
      # Extract content from response
      content = extract_content(data)
      
      {
        content: content,
        usage: data["usage"],
        raw: data
      }
    end

    def web_search(query)
      # Use Anthropic's web search tool
      body = {
        model: @model,
        max_tokens: 4096,
        system: "You are a web research assistant. Search for the given query and return the results with URLs.",
        messages: [{ role: "user", content: "Search the web for: #{query}" }],
        tools: [{
          name: "web_search",
          description: "Search the web for information",
          input_schema: {
            type: "object",
            properties: {
              query: { type: "string", description: "The search query" }
            },
            required: ["query"]
          }
        }]
      }

      response = HTTParty.post(
        API_URL,
        headers: {
          "Content-Type" => "application/json",
          "x-api-key" => @api_key,
          "anthropic-version" => "2023-06-01"
        },
        body: body.to_json
      )

      unless response.success?
        @logger.error("Web search error: #{response.code} - #{response.body}")
        return []
      end

      data = JSON.parse(response.body)
      extract_search_results(data)
    end

    def web_search_available?
      # Anthropic supports web search via tools
      true
    end

    def code_execution_available?
      # Anthropic doesn't natively support code execution
      false
    end

    def file_output_available?
      true
    end

    def attachments_available?
      true
    end

    def long_output_available?
      true
    end

    private

    def extract_content(data)
      content_blocks = data.dig("content") || []
      
      # Check for tool use
      tool_use = content_blocks.find { |b| b["type"] == "tool_use" }
      if tool_use
        return tool_use["input"]
      end
      
      # Otherwise get text content
      text_blocks = content_blocks.select { |b| b["type"] == "text" }
      text_blocks.map { |b| b["text"] }.join("\n")
    end

    def extract_search_results(data)
      results = []
      content_blocks = data.dig("content") || []
      
      content_blocks.each do |block|
        if block["type"] == "tool_result"
          # Extract URLs from tool results
          content = block["content"] || []
          content.each do |item|
            if item["type"] == "text"
              # Parse search results from text
              text = item["text"]
              # This is simplified - actual parsing depends on format
              results << { title: "Search result", url: "", snippet: text }
            end
          end
        end
      end
      
      results
    end
  end

  class LLMError < StandardError; end
end
