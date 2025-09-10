{
  title: "RAG Utilities",
  description: "Custom utility functions for RAG email response system",
  version: "1.0",
  
  # ==========================================
  # CONNECTION CONFIGURATION
  # ==========================================
  connection: {
    fields: [
      {
        name: "environment",
        label: "Environment",
        hint: "Select the environment for the connector",
        optional: false,
        control_type: "select",
        # Use options (not pick_list) inside connection
        options: [
          ["Development", "dev"],
          ["Staging", "staging"],
          ["Production", "prod"]
        ]
      },
      {
        name: "chunk_size_default",
        label: "Default Chunk Size",
        hint: "Default token size for text chunks",
        optional: true,
        type: "integer",
        control_type: "integer",
        default: 1000
      },
      {
        name: "chunk_overlap_default",
        label: "Default Chunk Overlap",
        hint: "Default token overlap between chunks",
        optional: true,
        type: "integer",
        control_type: "integer",
        default: 100
      },
      {
        name: "similarity_threshold",
        label: "Similarity Threshold",
        hint: "Minimum similarity score (0–1)",
        optional: true,
        type: "number",
        control_type: "number",
        default: 0.7
      }
    ],
    
    authorization: {
      type: "custom_auth",
      apply: lambda do |connection|
        headers("X-Environment": connection["environment"])
      end
    }
  },
  
  # ==========================================
  # CONNECTION TEST
  # ==========================================
  test: lambda do |connection|
    {
      environment: connection["environment"],
      chunk_size: connection["chunk_size_default"],
      status: "connected"
    }
  end,
  
  # ==========================================
  # ACTIONS
  # ==========================================
  actions: {
    
    # 1. SMART CHUNK TEXT
    smart_chunk_text: {
      title: "Smart Chunk Text",
      subtitle: "Intelligently chunk text preserving context",
      description: "Splits text into chunks with smart boundaries and overlap",

      input_fields: lambda do
        [
          { name: "text", label: "Input Text", type: "string", optional: false, control_type: "text-area" },
          { name: "chunk_size", label: "Chunk Size (tokens)", type: "integer", optional: true, default: 1000, hint: "Maximum tokens per chunk" },
          { name: "chunk_overlap", label: "Chunk Overlap (tokens)", type: "integer", optional: true, default: 100, hint: "Token overlap between chunks" },
          { name: "preserve_sentences", label: "Preserve Sentences", type: "boolean", optional: true, default: true, hint: "Don't break mid-sentence" },
          { name: "preserve_paragraphs", label: "Preserve Paragraphs", type: "boolean", optional: true, default: false, hint: "Try to keep paragraphs intact" }
        ]
      end,

      output_fields: lambda do
        [
          {
            name: "chunks",
            type: "array",
            of: "object",
            properties: [
              { name: "chunk_id", type: "string" },
              { name: "chunk_index", type: "integer" },
              { name: "text", type: "string" },
              { name: "token_count", type: "integer" },
              { name: "start_char", type: "integer" },
              { name: "end_char", type: "integer" },
              { name: "metadata", type: "object" }
            ]
          },
          { name: "total_chunks", type: "integer" },
          { name: "total_tokens", type: "integer" }
        ]
      end,

      execute: lambda do |connection, input|
        # Fallback to connection defaults if not provided
        input["chunk_size"] ||= (connection["chunk_size_default"] || 1000).to_i
        input["chunk_overlap"] ||= (connection["chunk_overlap_default"] || 100).to_i
        call(:chunk_text_with_overlap, input)
      end
    },
    
    # 2. CLEAN EMAIL TEXT
    clean_email_text: {
      title: "Clean Email Text",
      subtitle: "Preprocess email content for RAG",
      description: "Removes signatures, quotes, and normalizes email text",

      input_fields: lambda do
        [
          { name: "email_body", label: "Email Body", type: "string", optional: false, control_type: "text-area" },
          { name: "remove_signatures", label: "Remove Signatures", type: "boolean", optional: true, default: true },
          { name: "remove_quotes", label: "Remove Quoted Text", type: "boolean", optional: true, default: true },
          { name: "remove_disclaimers", label: "Remove Disclaimers", type: "boolean", optional: true, default: true },
          { name: "normalize_whitespace", label: "Normalize Whitespace", type: "boolean", optional: true, default: true },
          { name: "extract_urls", label: "Extract URLs", type: "boolean", optional: true, default: false }
        ]
      end,

      output_fields: lambda do
        [
          { name: "cleaned_text", type: "string" },
          { name: "extracted_query", type: "string" },
          { name: "removed_sections", type: "array", of: "string" },
          { name: "extracted_urls", type: "array", of: "string" },
          { name: "original_length", type: "integer" },
          { name: "cleaned_length", type: "integer" },
          { name: "reduction_percentage", type: "number" }
        ]
      end,

      execute: lambda do |_connection, input|
        call(:process_email_text, input)
      end
    },

    # 3. CALCULATE SIMILARITY
    calculate_similarity: {
      title: "Calculate Vector Similarity",
      subtitle: "Cosine / Euclidean / Dot product",
      description: "Computes similarity scores for vector embeddings",

      input_fields: lambda do
        [
          { name: "vector_a", label: "Vector A", type: "array", of: "number", optional: false, hint: "First embedding vector" },
          { name: "vector_b", label: "Vector B", type: "array", of: "number", optional: false, hint: "Second embedding vector" },
          { name: "similarity_type", label: "Similarity Type", type: "string", optional: true, default: "cosine", control_type: "select", pick_list: "similarity_types" },
          { name: "normalize", label: "Normalize Vectors", type: "boolean", optional: true, default: true }
        ]
      end,

      output_fields: lambda do
        [
          { name: "similarity_score", type: "number" },
          { name: "similarity_percentage", type: "number" },
          { name: "is_similar", type: "boolean" },
          { name: "similarity_type", type: "string" },
          { name: "computation_time_ms", type: "integer" }
        ]
      end,

      execute: lambda do |connection, input|
        call(:compute_similarity, input, connection)
      end
    },
    
    # 4. FORMAT EMBEDDINGS BATCH
    format_embeddings_batch: {
      title: "Format Embeddings for Vertex AI",
      subtitle: "Format embeddings for batch processing",
      description: "Prepares embedding data for Vertex AI Vector Search",

      input_fields: lambda do
        [
          {
            name: "embeddings",
            label: "Embeddings Data",
            type: "array",
            of: "object",
            properties: [
              { name: "id", type: "string" },
              { name: "vector", type: "array", of: "number" },
              { name: "metadata", type: "object" }
            ],
            optional: false
          },
          { name: "index_endpoint", label: "Index Endpoint ID", type: "string", optional: false },
          { name: "batch_size", label: "Batch Size", type: "integer", optional: true, default: 25, hint: "Embeddings per batch" },
          { name: "format_type", label: "Format Type", type: "string", optional: true, default: "json", control_type: "select", pick_list: "format_types" }
        ]
      end,

      output_fields: lambda do
        [
          {
            name: "formatted_batches",
            type: "array",
            of: "object",
            properties: [
              { name: "batch_id", type: "string" },
              { name: "batch_number", type: "integer" },
              {
                name: "datapoints",
                type: "array",
                of: "object",
                properties: [
                  { name: "datapoint_id", type: "string" },
                  { name: "feature_vector", type: "array", of: "number" },
                  { name: "restricts", type: "object" }
                ]
              },
              { name: "size", type: "integer" }
            ]
          },
          { name: "total_batches", type: "integer" },
          { name: "total_embeddings", type: "integer" },
          { name: "index_endpoint", type: "string" }
        ]
      end,

      execute: lambda do |_connection, input|
        call(:format_for_vertex_ai, input)
      end
    },
    
    # 5. BUILD RAG PROMPT
    build_rag_prompt: {
      title: "Build RAG Prompt",
      subtitle: "Construct optimized RAG prompt",
      description: "Creates a prompt with context and query for LLM",

      input_fields: lambda do
        [
          { name: "query", label: "User Query", type: "string", optional: false, control_type: "text-area" },
          {
            name: "context_documents",
            label: "Context Documents",
            type: "array",
            of: "object",
            properties: [
              { name: "content", type: "string" },
              { name: "relevance_score", type: "number" },
              { name: "source", type: "string" },
              { name: "metadata", type: "object" }
            ],
            optional: false
          },
          { name: "prompt_template", label: "Prompt Template", type: "string", optional: true, control_type: "select", pick_list: "prompt_templates" },
          { name: "max_context_length", label: "Max Context Length", type: "integer", optional: true, default: 3000 },
          { name: "include_metadata", label: "Include Metadata", type: "boolean", optional: true, default: false },
          { name: "system_instructions", label: "System Instructions", type: "string", optional: true, control_type: "text-area" }
        ]
      end,

      output_fields: lambda do
        [
          { name: "formatted_prompt", type: "string" },
          { name: "token_count", type: "integer" },
          { name: "context_used", type: "integer" },
          { name: "truncated", type: "boolean" },
          { name: "prompt_metadata", type: "object" }
        ]
      end,

      execute: lambda do |_connection, input|
        call(:construct_rag_prompt, input)
      end
    },

    # 6. VALIDATE LLM RESPONSE
    validate_llm_response: {
      title: "Validate LLM Response",
      subtitle: "Validate and score LLM output",
      description: "Checks response quality and relevance",

      input_fields: lambda do
        [
          { name: "response_text", label: "LLM Response", type: "string", optional: false, control_type: "text-area" },
          { name: "original_query", label: "Original Query", type: "string", optional: false },
          { name: "context_provided", label: "Context Documents", type: "array", of: "string", optional: true },
          {
            name: "validation_rules",
            label: "Validation Rules",
            type: "array",
            of: "object",
            properties: [
              { name: "rule_type", type: "string" },
              { name: "rule_value", type: "string" }
            ],
            optional: true
          },
          { name: "min_confidence", label: "Minimum Confidence", type: "number", optional: true, default: 0.7 }
        ]
      end,

      output_fields: lambda do
        [
          { name: "is_valid", type: "boolean" },
          { name: "confidence_score", type: "number" },
          { name: "validation_results", type: "object" },
          { name: "issues_found", type: "array", of: "string" },
          { name: "requires_human_review", type: "boolean" },
          { name: "suggested_improvements", type: "array", of: "string" }
        ]
      end,

      execute: lambda do |connection, input|
        call(:validate_response, input, connection)
      end
    },

    # 7. GENERATE DOCUMENT METADATA
    generate_document_metadata: {
      title: "Generate Document Metadata",
      subtitle: "Extract metadata from documents",
      description: "Generates comprehensive metadata for document indexing",

      input_fields: lambda do
        [
          { name: "document_content", label: "Document Content", type: "string", optional: false, control_type: "text-area" },
          { name: "file_path", label: "File Path", type: "string", optional: false },
          { name: "file_type", label: "File Type", type: "string", optional: true, control_type: "select", pick_list: "file_types" },
          { name: "extract_entities", label: "Extract Entities", type: "boolean", optional: true, default: true },
          { name: "generate_summary", label: "Generate Summary", type: "boolean", optional: true, default: true }
        ]
      end,

      output_fields: lambda do
        [
          { name: "document_id", type: "string" },
          { name: "file_hash", type: "string" },
          { name: "word_count", type: "integer" },
          { name: "character_count", type: "integer" },
          { name: "estimated_tokens", type: "integer" },
          { name: "language", type: "string" },
          { name: "summary", type: "string" },
          { name: "key_topics", type: "array", of: "string" },
          { name: "entities", type: "object" },
          { name: "created_at", type: "timestamp" },
          { name: "processing_time_ms", type: "integer" }
        ]
      end,

      execute: lambda do |_connection, input|
        call(:extract_metadata, input)
      end
    },

    # 8. CHECK DOCUMENT CHANGES
    check_document_changes: {
      title: "Check Document Changes",
      subtitle: "Detect changes in documents",
      description: "Compares document versions to detect modifications",

      input_fields: lambda do
        [
          { name: "current_hash", label: "Current Document Hash", type: "string", optional: false },
          { name: "current_content", label: "Current Content", type: "string", optional: true, control_type: "text-area" },
          { name: "previous_hash", label: "Previous Document Hash", type: "string", optional: false },
          { name: "previous_content", label: "Previous Content", type: "string", optional: true, control_type: "text-area" },
          { name: "check_type", label: "Check Type", type: "string", optional: true, default: "hash", control_type: "select", pick_list: "check_types" }
        ]
      end,

      output_fields: lambda do
        [
          { name: "has_changed", type: "boolean" },
          { name: "change_type", type: "string" },
          { name: "change_percentage", type: "number" },
          { name: "added_content", type: "array", of: "string" },
          { name: "removed_content", type: "array", of: "string" },
          { name: "modified_sections", type: "array", of: "object" },
          { name: "requires_reindexing", type: "boolean" }
        ]
      end,

      execute: lambda do |_connection, input|
        call(:detect_changes, input)
      end
    },

    # 9. CALCULATE METRICS
    calculate_metrics: {
      title: "Calculate Performance Metrics",
      subtitle: "Calculate system performance metrics",
      description: "Computes various performance and efficiency metrics",

      input_fields: lambda do
        [
          { name: "metric_type", label: "Metric Type", type: "string", optional: false, control_type: "select", pick_list: "metric_types" },
          {
            name: "data_points",
            label: "Data Points",
            type: "array",
            of: "object",
            properties: [
              { name: "timestamp", type: "timestamp" },
              { name: "value", type: "number" },
              { name: "metadata", type: "object" }
            ],
            optional: false
          },
          { name: "aggregation_period", label: "Aggregation Period", type: "string", optional: true, default: "hour", control_type: "select", pick_list: "time_periods" },
          { name: "include_percentiles", label: "Include Percentiles", type: "boolean", optional: true, default: true }
        ]
      end,

      output_fields: lambda do
        [
          { name: "average", type: "number" },
          { name: "median", type: "number" },
          { name: "min", type: "number" },
          { name: "max", type: "number" },
          { name: "std_deviation", type: "number" },
          { name: "percentile_95", type: "number" },
          { name: "percentile_99", type: "number" },
          { name: "total_count", type: "integer" },
          { name: "trend", type: "string" },
          { name: "anomalies_detected", type: "array", of: "object" }
        ]
      end,

      execute: lambda do |_connection, input|
        call(:compute_metrics, input)
      end
    },

    # 10. OPTIMIZE BATCH SIZE
    optimize_batch_size: {
      title: "Optimize Batch Size",
      subtitle: "Calculate optimal batch size for processing",
      description: "Determines optimal batch size based on performance data",

      input_fields: lambda do
        [
          { name: "total_items", label: "Total Items to Process", type: "integer", optional: false },
          {
            name: "processing_history",
            label: "Processing History",
            type: "array",
            of: "object",
            properties: [
              { name: "batch_size", type: "integer" },
              { name: "processing_time", type: "number" },
              { name: "success_rate", type: "number" },
              { name: "memory_usage", type: "number" }
            ],
            optional: true
          },
          { name: "optimization_target", label: "Optimization Target", type: "string", optional: true, default: "throughput", control_type: "select", pick_list: "optimization_targets" },
          { name: "max_batch_size", label: "Maximum Batch Size", type: "integer", optional: true, default: 100 },
          { name: "min_batch_size", label: "Minimum Batch Size", type: "integer", optional: true, default: 10 }
        ]
      end,

      output_fields: lambda do
        [
          { name: "optimal_batch_size", type: "integer" },
          { name: "estimated_batches", type: "integer" },
          { name: "estimated_processing_time", type: "number" },
          { name: "throughput_estimate", type: "number" },
          { name: "confidence_score", type: "number" },
          { name: "recommendation_reason", type: "string" }
        ]
      end,

      execute: lambda do |_connection, input|
        call(:calculate_optimal_batch, input)
      end
    }
  },
  
  # ==========================================
  # METHODS (Helper Functions)
  # ==========================================
  methods: {
    chunk_text_with_overlap: lambda do |input|
      text = input["text"] || ""
      chunk_size = (input["chunk_size"] || 1000).to_i
      overlap = (input["chunk_overlap"] || 100).to_i
      preserve_sentences = !!input["preserve_sentences"]
      preserve_paragraphs = !!input["preserve_paragraphs"]

      # Token estimation (rough: 1 token ≈ 4 chars)
      chars_per_chunk = [chunk_size, 1].max * 4
      char_overlap = [[overlap, 0].max, chunk_size].min * 4

      chunks = []
      chunk_index = 0
      position = 0

      while position < text.length
        tentative_end = [position + chars_per_chunk, text.length].min
        chunk_end = tentative_end

        # Prefer paragraph boundary (double newline)
        if preserve_paragraphs && tentative_end < text.length
          rel = text[position...tentative_end].rindex(/\n{2,}/)
          chunk_end = position + rel + 1 if rel
        end

        # Then sentence boundary
        if preserve_sentences && chunk_end == tentative_end && tentative_end < text.length
          rel = text[position...tentative_end].rindex(/[.!?]["')\]]?\s/)
          chunk_end = position + rel + 1 if rel
        end

        chunk_end = tentative_end if chunk_end <= position # ensure forward progress
        chunk_text = text[position...chunk_end]

        chunks << {
          chunk_id: "chunk_#{chunk_index}",
          chunk_index: chunk_index,
          text: chunk_text,
          token_count: (chunk_text.length / 4.0).ceil,
          start_char: position,
          end_char: chunk_end,
          metadata: { has_overlap: chunk_index > 0, is_final: chunk_end >= text.length }
        }

        break if chunk_end >= text.length
        position = [chunk_end - char_overlap, 0].max
        chunk_index += 1
      end

      {
        chunks: chunks,
        total_chunks: chunks.length,
        total_tokens: chunks.sum { |c| c[:token_count] }
      }
    end,

    process_email_text: lambda do |input|
      cleaned = (input["email_body"] || "").dup
      original_length = cleaned.length
      removed_sections = []
      extracted_urls = []

      # Normalize line endings early
      cleaned.gsub!("\r\n", "\n")

      # Signatures (keep patterns generous but bounded)
      if input["remove_signatures"]
        signature_patterns = [
          /^--\s*\n.*\z/m,
          /^Best regards,.*\z/mi,
          /^Sincerely,.*\z/mi,
          /^Thanks,.*\z/mi,
          /^Sent from my.*\z/mi
        ]
        signature_patterns.each do |pattern|
          if (m = cleaned.match(pattern))
            removed_sections << m[0]
            cleaned.gsub!(pattern, "")
          end
        end
      end

      # Quoted text (each line starting with >)
      if input["remove_quotes"]
        cleaned.gsub!(/^[ \t]*>.*$/m) do |match|
          removed_sections << match
          ""
        end
      end

      # Disclaimers (simple footer-like blocks)
      if input["remove_disclaimers"]
        cleaned.gsub!(/(This email.*confidential.*)$/im) do |match|
          removed_sections << match
          ""
        end
      end

      # Extract URLs if requested
      if input["extract_urls"]
        extracted_urls = cleaned.scan(%r{https?://[^\s<>"'()]+})
      end

      # Normalize whitespace but keep paragraphs
      if input["normalize_whitespace"]
        cleaned.gsub!(/[ \t]+/, " ")
        cleaned.gsub!(/\n{3,}/, "\n\n")
        cleaned.strip!
      end

      # First non-empty paragraph (or first 200 chars fallback)
      extracted_query = cleaned.split(/\n{2,}/).find { |p| p.strip.length.positive? } || cleaned[0, 200]

      {
        cleaned_text: cleaned,
        extracted_query: extracted_query,
        removed_sections: removed_sections,
        extracted_urls: extracted_urls,
        original_length: original_length,
        cleaned_length: cleaned.length,
        reduction_percentage: (original_length.zero? ? 0 : ((1 - cleaned.length.to_f / original_length) * 100)).round(2)
      }
    end,

    compute_similarity: lambda do |input, connection|
      start_time = Time.now

      a = Array(input["vector_a"] || [])
      b = Array(input["vector_b"] || [])
      raise "Both vectors are required." if a.empty? || b.empty?
      raise "Vectors must be the same length." unless a.length == b.length

      normalize = input.key?("normalize") ? !!input["normalize"] : true
      type = (input["similarity_type"] || "cosine").to_s
      threshold = (connection["similarity_threshold"] || 0.7).to_f

      if normalize
        mag = Math.sqrt(a.sum { |x| x * x })
        a = a.map { |x| mag.zero? ? 0.0 : x / mag }
        mag = Math.sqrt(b.sum { |x| x * x })
        b = b.map { |x| mag.zero? ? 0.0 : x / mag }
      end

      dot = a.zip(b).sum { |x, y| x * y }
      mag_a = Math.sqrt(a.sum { |x| x * x })
      mag_b = Math.sqrt(b.sum { |x| x * x })

      score =
        case type
        when "cosine"
          (mag_a > 0 && mag_b > 0) ? dot / (mag_a * mag_b) : 0.0
        when "euclidean"
          dist = Math.sqrt(a.zip(b).sum { |x, y| (x - y) ** 2 })
          1.0 / (1.0 + dist) # map distance → similarity in (0,1]
        when "dot_product"
          dot # may be outside [-1,1] if not normalized
        else
          (mag_a > 0 && mag_b > 0) ? dot / (mag_a * mag_b) : 0.0
        end

      percent =
        case type
        when "cosine", "euclidean" then (score * 100).round(2)
        else nil
        end

      {
        similarity_score: score.round(6),
        similarity_percentage: percent,
        is_similar: score >= threshold,
        similarity_type: type,
        computation_time_ms: ((Time.now - start_time) * 1000).round
      }
    end,

    format_for_vertex_ai: lambda do |input|
      embeddings = input["embeddings"] || []
      batch_size = (input["batch_size"] || 25).to_i

      batches = []
      embeddings.each_slice(batch_size).with_index do |batch, index|
        formatted_batch = {
          batch_id: "batch_#{index}",
          batch_number: index,
          datapoints: batch.map do |emb|
            {
              datapoint_id: emb["id"],
              feature_vector: emb["vector"] || [],
              restricts: emb["metadata"] || {}
            }
          end,
          size: batch.length
        }
        batches << formatted_batch
      end

      {
        formatted_batches: batches,
        total_batches: batches.length,
        total_embeddings: embeddings.length,
        index_endpoint: input["index_endpoint"]
      }
    end,

    construct_rag_prompt: lambda do |input|
      query = input["query"] || ""
      context_docs = Array(input["context_documents"] || [])
      template = (input["prompt_template"] || "standard").to_s
      max_length = (input["max_context_length"] || 3000).to_i
      include_metadata = !!input["include_metadata"]
      system_instructions = input["system_instructions"]

      sorted_context = context_docs.sort_by { |doc| (doc["relevance_score"] || 0) }.reverse

      context_parts = []
      total_tokens = 0

      sorted_context.each do |doc|
        content = doc["content"].to_s
        doc_tokens = (content.length / 4.0).ceil
        break if doc_tokens > max_length && context_parts.empty?
        next if total_tokens + doc_tokens > max_length

        part = content.dup
        if include_metadata && doc["metadata"]
          part += "\nMetadata: #{doc["metadata"].to_json}"
        end
        context_parts << part
        total_tokens += doc_tokens
      end

      context_text = context_parts.join("\n\n---\n\n")

      prompt =
        case template
        when "standard"
          "Context:\n#{context_text}\n\nQuery: #{query}\n\nAnswer:"
        when "customer_service"
          "You are a customer service assistant. Use the following context to answer the customer's question.\n\nContext:\n#{context_text}\n\nCustomer Question: #{query}\n\nResponse:"
        when "technical"
          "You are a technical support specialist. Use the provided context to solve the technical issue.\n\nContext:\n#{context_text}\n\nTechnical Issue: #{query}\n\nSolution:"
        when "sales"
          "You are a sales representative. Use the context to address the sales inquiry.\n\nContext:\n#{context_text}\n\nSales Inquiry: #{query}\n\nResponse:"
        else
          "#{system_instructions}\n\nContext:\n#{context_text}\n\nQuery: #{query}\n\nAnswer:"
        end

      {
        formatted_prompt: prompt,
        token_count: (prompt.length / 4.0).ceil,
        context_used: context_parts.length,
        truncated: context_parts.length < sorted_context.length,
        prompt_metadata: { template: template, context_docs_used: context_parts.length, total_context_docs: sorted_context.length }
      }
    end,

    validate_response: lambda do |input, _connection|
      response = (input["response_text"] || "").to_s
      query = (input["original_query"] || "").to_s
      rules = Array(input["validation_rules"] || [])
      min_confidence = (input["min_confidence"] || 0.7).to_f

      issues = []
      confidence = 1.0

      if response.strip.empty?
        issues << "Response is empty"
        confidence -= 0.5
      elsif response.length < 10
        issues << "Response is too short"
        confidence -= 0.3
      end

      query_words = query.downcase.split(/\W+/).reject(&:empty?)
      response_words = response.downcase.split(/\W+/).reject(&:empty?)
      overlap = query_words.empty? ? 0.0 : ((query_words & response_words).length.to_f / query_words.length)

      if overlap < 0.1
        issues << "Response may not address the query"
        confidence -= 0.4
      end

      if response.include?("...") || response.include?("incomplete")
        issues << "Response appears incomplete"
        confidence -= 0.2
      end

      rules.each do |rule|
        case rule["rule_type"]
        when "contains"
          unless response.include?(rule["rule_value"].to_s)
            issues << "Response does not contain required text: #{rule["rule_value"]}"
            confidence -= 0.3
          end
        when "not_contains"
          if response.include?(rule["rule_value"].to_s)
            issues << "Response contains prohibited text: #{rule["rule_value"]}"
            confidence -= 0.3
          end
        end
      end

      {
        is_valid: confidence >= min_confidence,
        confidence_score: confidence.round(2),
        validation_results: { query_overlap: overlap.round(2), response_length: response.length, word_count: response_words.length },
        issues_found: issues,
        requires_human_review: confidence < 0.5,
        suggested_improvements: issues.empty? ? [] : ["Review and improve response quality"]
      }
    end,

    extract_metadata: lambda do |input|
      require "digest"

      content = input["document_content"].to_s
      file_path = input["file_path"].to_s
      extract_entities = input.key?("extract_entities") ? !!input["extract_entities"] : true
      generate_summary = input.key?("generate_summary") ? !!input["generate_summary"] : true

      start_time = Time.now

      word_count = content.split(/\s+/).reject(&:empty?).length
      char_count = content.length
      estimated_tokens = (content.length / 4.0).ceil

      language = content.match?(/[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ]/i) ? "non-english" : "english"

      summary = generate_summary ? (content[0, 200].to_s + (content.length > 200 ? "..." : "")) : ""

      key_topics = []
      if extract_entities
        common = %w[the a an and or but in on at to for of with by from is are was were be been being this that these those there here then than into out over under after before about as it its it's their them they our we you your he she his her him not will would can could should may might must also just more most other some such]
        words = content.downcase.scan(/[a-z0-9\-]+/).reject { |w| w.length < 4 || common.include?(w) }
        freq = words.each_with_object(Hash.new(0)) { |w, h| h[w] += 1 }
        key_topics = freq.sort_by { |_, c| -c }.first(5).map(&:first)
      end

      file_hash = Digest::SHA256.hexdigest(content)
      document_id = Digest::SHA1.hexdigest("#{file_path}|#{file_hash}")

      {
        document_id: document_id,
        file_hash: file_hash,
        word_count: word_count,
        character_count: char_count,
        estimated_tokens: estimated_tokens,
        language: language,
        summary: summary,
        key_topics: key_topics,
        entities: { people: [], organizations: [], locations: [] },
        created_at: Time.now.iso8601,
        processing_time_ms: ((Time.now - start_time) * 1000).round
      }
    end,

    detect_changes: lambda do |input|
      current_hash = input["current_hash"]
      current_content = input["current_content"]
      previous_hash = input["previous_hash"]
      previous_content = input["previous_content"]
      check_type = (input["check_type"] || "hash").to_s

      has_changed = current_hash != previous_hash
      change_type = "none"
      change_percentage = 0.0
      added = []
      removed = []
      modified = []

      if has_changed
        change_type = "hash_changed"

        if check_type == "content" && current_content && previous_content
          current_lines = current_content.split("\n")
          previous_lines = previous_content.split("\n")

          added = current_lines - previous_lines
          removed = previous_lines - current_lines

          total_lines = [current_lines.length, previous_lines.length].max
          change_percentage = total_lines.zero? ? 0.0 : (((added.length + removed.length).to_f / total_lines) * 100).round(2)
          change_type = "content_changed"
        end
      end

      {
        has_changed: has_changed,
        change_type: change_type,
        change_percentage: change_percentage,
        added_content: added,
        removed_content: removed,
        modified_sections: modified,
        requires_reindexing: has_changed
      }
    end,

    compute_metrics: lambda do |input|
      data_points = Array(input["data_points"] || [])
      values = data_points.map { |dp| dp["value"].to_f }.sort

      return {
        average: 0, median: 0, min: 0, max: 0,
        std_deviation: 0, percentile_95: 0, percentile_99: 0,
        total_count: 0, trend: "stable", anomalies_detected: []
      } if values.empty?

      avg = values.sum.to_f / values.length
      median = values.length.odd? ? values[values.length / 2] : (values[values.length / 2 - 1] + values[values.length / 2]) / 2.0
      min = values.first
      max = values.last

      variance = values.map { |v| (v - avg)**2 }.sum / values.length
      std_dev = Math.sqrt(variance)

      percentile = lambda do |arr, p|
        return 0 if arr.empty?
        idx = (p / 100.0 * (arr.length - 1)).round
        arr[idx]
      end

      p95 = percentile.call(values, 95)
      p99 = percentile.call(values, 99)

      half = values.length / 2
      first_half_avg = values[0...half].empty? ? avg : (values[0...half].sum.to_f / [half, 1].max)
      second_half_avg = values[half..-1].empty? ? avg : (values[half..-1].sum.to_f / [values.length - half, 1].max)
      trend =
        if second_half_avg > first_half_avg * 1.1
          "increasing"
        elsif second_half_avg < first_half_avg * 0.9
          "decreasing"
        else
          "stable"
        end

      anomalies = data_points.select { |dp| (dp["value"].to_f - avg).abs > 2 * std_dev }.map { |dp| { timestamp: dp["timestamp"], value: dp["value"] } }

      {
        average: avg.round(2),
        median: median.round(2),
        min: min,
        max: max,
        std_deviation: std_dev.round(2),
        percentile_95: p95.round(2),
        percentile_99: p99.round(2),
        total_count: values.length,
        trend: trend,
        anomalies_detected: anomalies
      }
    end,

    calculate_optimal_batch: lambda do |input|
      total_items = (input["total_items"] || 0).to_i
      history = Array(input["processing_history"] || [])
      target = (input["optimization_target"] || "throughput").to_s
      max_batch = (input["max_batch_size"] || 100).to_i
      min_batch = (input["min_batch_size"] || 10).to_i

      if history.empty?
        optimal = [[total_items / 10, max_batch].min, min_batch].max
        return {
          optimal_batch_size: optimal,
          estimated_batches: (optimal.zero? ? 0 : (total_items.to_f / optimal).ceil),
          estimated_processing_time: 0.0,
          throughput_estimate: 0.0,
          confidence_score: 0.5,
          recommendation_reason: "No history available, using default calculation"
        }
      end

      optimal =
        case target
        when "throughput"
          best = history.max_by { |h| h["batch_size"].to_f / [h["processing_time"].to_f, 0.0001].max }
          best["batch_size"].to_i
        when "latency"
          best = history.min_by { |h| h["processing_time"].to_f / [h["batch_size"].to_f, 1].max }
          best["batch_size"].to_i
        else
          (history.sum { |h| h["batch_size"].to_i } / [history.length, 1].max)
        end

      optimal = [[optimal, max_batch].min, min_batch].max
      estimated_batches = (optimal.zero? ? 0 : (total_items.to_f / optimal).ceil)
      avg_time = history.sum { |h| h["processing_time"].to_f } / [history.length, 1].max
      estimated_time = avg_time * estimated_batches
      throughput = estimated_time.zero? ? 0.0 : (total_items.to_f / estimated_time)

      {
        optimal_batch_size: optimal,
        estimated_batches: estimated_batches,
        estimated_processing_time: estimated_time.round(2),
        throughput_estimate: throughput.round(2),
        confidence_score: 0.8,
        recommendation_reason: "Based on historical performance data"
      }
    end
  },
  
  # ==========================================
  # OBJECT DEFINITIONS (Schemas)
  # ==========================================
  object_definitions: {
    chunk_object: {
      fields: lambda do
        [
          { name: "chunk_id", type: "string" },
          { name: "chunk_index", type: "integer" },
          { name: "text", type: "string" },
          { name: "token_count", type: "integer" },
          { name: "start_char", type: "integer" },
          { name: "end_char", type: "integer" },
          { name: "metadata", type: "object" }
        ]
      end
    },
    embedding_object: {
      fields: lambda do
        [
          { name: "id", type: "string" },
          { name: "vector", type: "array", of: "number" },
          { name: "metadata", type: "object" }
        ]
      end
    },
    metric_datapoint: {
      fields: lambda do
        [
          { name: "timestamp", type: "timestamp" },
          { name: "value", type: "number" },
          { name: "metadata", type: "object" }
        ]
      end
    }
  },
  
  # ==========================================
  # PICK LISTS (Dropdown Options)
  # ==========================================
  pick_lists: {
    similarity_types: lambda do
      [
        ["Cosine Similarity", "cosine"],
        ["Euclidean Distance", "euclidean"],
        ["Dot Product", "dot_product"]
      ]
    end,
    format_types: lambda do
      [
        ["JSON", "json"],
        ["JSONL", "jsonl"],
        ["CSV", "csv"]
      ]
    end,
    prompt_templates: lambda do
      [
        ["Standard RAG", "standard"],
        ["Customer Service", "customer_service"],
        ["Technical Support", "technical"],
        ["Sales Inquiry", "sales"],
        ["Custom", "custom"]
      ]
    end,
    file_types: lambda do
      [
        ["PDF", "pdf"],
        ["Word Document", "docx"],
        ["Text File", "txt"],
        ["Markdown", "md"],
        ["HTML", "html"]
      ]
    end,
    check_types: lambda do
      [
        ["Hash Only", "hash"],
        ["Content Diff", "content"]
      ]
    end,
    metric_types: lambda do
      [
        ["Response Time", "response_time"],
        ["Token Usage", "token_usage"],
        ["Cache Hit Rate", "cache_hit"],
        ["Error Rate", "error_rate"],
        ["Throughput", "throughput"]
      ]
    end,
    time_periods: lambda do
      [
        ["Minute", "minute"],
        ["Hour", "hour"],
        ["Day", "day"],
        ["Week", "week"]
      ]
    end,
    optimization_targets: lambda do
      [
        ["Throughput", "throughput"],
        ["Latency", "latency"],
        ["Cost", "cost"],
        ["Accuracy", "accuracy"]
      ]
    end
  }
}