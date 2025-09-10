# RAG Utilities Connector for Workato

## Overview

The **RAG Utilities Connector** is a custom Workato connector designed to provide essential utility functions for building Retrieval-Augmented Generation (RAG) systems, particularly focused on email response automation. This connector offers a comprehensive suite of text processing, vector operations, and optimization tools to streamline RAG pipeline development.

## Version
- **Current Version**: 1.0

## Features

### Core Capabilities
- **Smart Text Chunking** - Intelligent document splitting with overlap and boundary preservation
- **Email Processing** - Advanced email cleaning and preprocessing
- **Vector Operations** - Similarity calculations for embeddings
- **Vertex AI Integration** - Format embeddings for Google Vertex AI Vector Search
- **Prompt Engineering** - Dynamic RAG prompt construction
- **Response Validation** - LLM output quality checks
- **Document Management** - Metadata extraction and change detection
- **Performance Analytics** - Metrics calculation and batch optimization

## Installation & Setup

### Prerequisites
- Workato account with custom connector capabilities
- Access to create custom connectors in your Workato workspace

### Configuration

#### Connection Settings
When setting up the connector, you'll need to configure:

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `environment` | Select | Yes | Environment selection (dev/staging/prod) | - |
| `chunk_size_default` | Integer | No | Default token size for text chunks | 1000 |
| `chunk_overlap_default` | Integer | No | Default token overlap between chunks | 100 |
| `similarity_threshold` | Number | No | Minimum similarity score (0-1) | 0.7 |

## Available Actions

### 1. Smart Chunk Text
**Purpose**: Intelligently splits text into chunks while preserving context

**Input Parameters**:
- `text` (required): Input text to chunk
- `chunk_size`: Maximum tokens per chunk (default: 1000)
- `chunk_overlap`: Token overlap between chunks (default: 100)
- `preserve_sentences`: Don't break mid-sentence (default: true)
- `preserve_paragraphs`: Try to keep paragraphs intact (default: false)

**Output**:
```json
{
  "chunks": [
    {
      "chunk_id": "chunk_0",
      "chunk_index": 0,
      "text": "...",
      "token_count": 250,
      "start_char": 0,
      "end_char": 1000,
      "metadata": {...}
    }
  ],
  "total_chunks": 5,
  "total_tokens": 1250
}
```

### 2. Clean Email Text
**Purpose**: Preprocess email content for RAG processing

**Input Parameters**:
- `email_body` (required): Raw email content
- `remove_signatures`: Remove email signatures (default: true)
- `remove_quotes`: Remove quoted text (default: true)
- `remove_disclaimers`: Remove legal disclaimers (default: true)
- `normalize_whitespace`: Clean up spacing (default: true)
- `extract_urls`: Extract URLs from content (default: false)

**Output**:
- Cleaned text with metadata about removed sections and reduction percentage

### 3. Calculate Similarity
**Purpose**: Compute similarity scores between vector embeddings

**Supported Methods**:
- Cosine similarity
- Euclidean distance
- Dot product

**Input Parameters**:
- `vector_a`, `vector_b` (required): Embedding vectors to compare
- `similarity_type`: Calculation method (default: cosine)
- `normalize`: Normalize vectors before calculation (default: true)

### 4. Format Embeddings Batch
**Purpose**: Prepare embeddings for Vertex AI Vector Search

**Input Parameters**:
- `embeddings`: Array of embedding objects
- `index_endpoint`: Vertex AI index endpoint ID
- `batch_size`: Embeddings per batch (default: 25)
- `format_type`: Output format (json/jsonl/csv)

### 5. Build RAG Prompt
**Purpose**: Construct optimized prompts for LLM with context

**Templates Available**:
- Standard RAG
- Customer Service
- Technical Support
- Sales Inquiry
- Custom

**Input Parameters**:
- `query` (required): User query
- `context_documents` (required): Retrieved context documents
- `prompt_template`: Template selection
- `max_context_length`: Maximum context tokens (default: 3000)

### 6. Validate LLM Response
**Purpose**: Check response quality and relevance

**Features**:
- Confidence scoring
- Query-response relevance checking
- Custom validation rules
- Human review flagging

### 7. Generate Document Metadata
**Purpose**: Extract comprehensive metadata for document indexing

**Extracts**:
- Document hash and ID
- Word/character/token counts
- Language detection
- Auto-generated summary
- Key topics extraction
- Entity recognition placeholders

### 8. Check Document Changes
**Purpose**: Detect modifications between document versions

**Detection Methods**:
- Hash comparison
- Content diff analysis
- Change percentage calculation

### 9. Calculate Metrics
**Purpose**: Compute performance and efficiency metrics

**Metric Types**:
- Response time
- Token usage
- Cache hit rate
- Error rate
- Throughput

**Statistical Outputs**:
- Average, median, min, max
- Standard deviation
- 95th and 99th percentiles
- Trend analysis
- Anomaly detection

### 10. Optimize Batch Size
**Purpose**: Determine optimal batch size for processing

**Optimization Targets**:
- Throughput maximization
- Latency minimization
- Cost optimization
- Accuracy optimization

## Usage Examples

### Example 1: Processing Email for RAG
```ruby
# Step 1: Clean the email
cleaned = call('clean_email_text', {
  email_body: raw_email,
  remove_signatures: true,
  remove_quotes: true
})

# Step 2: Chunk the cleaned text
chunks = call('smart_chunk_text', {
  text: cleaned['cleaned_text'],
  chunk_size: 500,
  preserve_sentences: true
})

# Step 3: Process chunks (embeddings would be generated here)
# ... embedding generation ...

# Step 4: Build RAG prompt
prompt = call('build_rag_prompt', {
  query: cleaned['extracted_query'],
  context_documents: relevant_chunks,
  prompt_template: 'customer_service'
})
```

### Example 2: Vector Similarity Search
```ruby
# Calculate similarity between query and document embeddings
similarity = call('calculate_similarity', {
  vector_a: query_embedding,
  vector_b: document_embedding,
  similarity_type: 'cosine'
})

if similarity['is_similar']
  # Document is relevant
  add_to_context(document)
end
```

## Best Practices

### Text Chunking
- Use **1000-1500 tokens** for general documents
- Enable `preserve_sentences` for better context
- Use 10-20% overlap for continuity
- Enable `preserve_paragraphs` for structured documents

### Email Processing
- Always clean emails before chunking
- Extract URLs separately if they're important
- Save removed sections for audit trails

### Vector Operations
- Normalize vectors for cosine similarity
- Use appropriate similarity threshold (0.7-0.8 typical)
- Cache similarity calculations when possible

### Batch Processing
- Start with smaller batches and scale up
- Monitor memory usage and processing time
- Use the optimize_batch_size action for data-driven decisions

## Technical Details

### Token Estimation
- The connector uses a rough estimation of **1 token ≈ 4 characters**
- Adjust chunk sizes based on your specific tokenizer

### Supported File Types
- PDF
- Word Documents (docx)
- Text files (txt)
- Markdown (md)
- HTML

### Performance Considerations
- Chunking is memory-efficient with streaming processing
- Vector operations are optimized for arrays up to 10,000 dimensions
- Batch formatting supports up to 1000 embeddings per call

## Error Handling

The connector includes built-in error handling for:
- Empty or invalid inputs
- Vector dimension mismatches
- Invalid configuration values
- Processing timeouts

All actions return detailed error messages and suggestions for resolution.

## Limitations

- Maximum text size per chunking operation: 1MB
- Maximum vector dimensions: 10,000
- Maximum batch size: 1000 items
- Token estimation is approximate

## Support & Contribution

For issues, feature requests, or contributions:
1. Check the action's built-in documentation
2. Review error messages and validation results
3. Consult Workato's custom connector documentation

## Changelog

### Version 1.0 (Initial Release)
- ✅ Core text processing utilities
- ✅ Vector similarity calculations
- ✅ Vertex AI formatting support
- ✅ Email preprocessing
- ✅ Document metadata extraction
- ✅ Performance metrics calculation
- ✅ Batch optimization algorithms

## License

This connector is provided as-is for use within Workato environments. Ensure compliance with your organization's data processing and security policies when handling sensitive information.

