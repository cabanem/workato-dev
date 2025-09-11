# Help Text for RAG Utilities Connector

## Connector-Level Help Text

### Main Description
```
Utility functions for RAG (Retrieval-Augmented Generation) email response systems. Provides text chunking, email cleaning, vector operations, and document processing tools.
```

### Connection Setup
```
Configure default settings for text processing. These can be overridden in individual actions. Environment selection determines logging verbosity and processing limits.
```

## Connection Field Help Text

### Environment
```
Select the environment for processing. Development has verbose logging, Production has optimized performance.
```

### Default Chunk Size
```
Number of tokens per text chunk. Typical range: 500-2000. Larger chunks retain more context but may exceed model limits.
```

### Default Chunk Overlap
```
Tokens repeated between consecutive chunks to maintain context. Typically 10-20% of chunk size.
```

### Similarity Threshold
```
Minimum score (0-1) to consider vectors similar. 0.7-0.8 for semantic similarity, 0.9+ for near-duplicates.
```

## Action Help Text

### Smart Chunk Text
```
Splits large documents into overlapping chunks while preserving sentence and paragraph boundaries. Essential for processing documents that exceed LLM context windows.
```

### Clean Email Text
```
Removes signatures, quoted replies, and disclaimers from emails. Extracts the actual query for more focused RAG processing. Reduces noise and improves response relevance.
```

### Calculate Similarity
```
Compares two embedding vectors to determine semantic similarity. Use cosine for normalized embeddings, euclidean for distance-based matching.
```

### Format Embeddings Batch
```
Prepares embedding data for bulk upload to Vertex AI Vector Search. Automatically handles batching and formatting requirements.
```

### Build RAG Prompt
```
Combines user query with retrieved context into an optimized LLM prompt. Automatically manages token limits and sorts context by relevance.
```

### Validate LLM Response
```
Checks if the generated response addresses the query and meets quality standards. Helps identify responses needing human review.
```

### Generate Document Metadata
```
Extracts searchable metadata from documents for better retrieval. Includes automatic summarization and topic extraction.
```

### Check Document Changes
```
Detects if a document has been modified since last processing. Use to trigger re-indexing only when necessary.
```

### Calculate Metrics
```
Analyzes performance data to identify trends and anomalies. Supports capacity planning and optimization decisions.
```

### Optimize Batch Size
```
Determines ideal batch size based on historical performance. Balances throughput and resource usage.
```

## Common Parameter Help Text

### Text/Email Body
```
Input text to process. Supports up to 1MB. For larger documents, pre-split into sections.
```

### Chunk Size
```
Target size for each text chunk in tokens (1 token ≈ 4 characters). Consider your LLM's context window.
```

### Chunk Overlap
```
Number of tokens repeated between chunks. Higher overlap preserves more context but increases processing.
```

### Preserve Sentences
```
When enabled, avoids splitting text mid-sentence. Recommended for maintaining readability.
```

### Preserve Paragraphs
```
Attempts to keep paragraphs together. Best for structured documents. May create uneven chunk sizes.
```

### Vector A/B
```
Embedding vectors as number arrays. Must be same dimension. Example: [0.1, -0.2, 0.3, ...]
```

### Similarity Type
```
Cosine: Direction-based (most common). Euclidean: Distance-based. Dot Product: Magnitude-aware.
```

### Context Documents
```
Retrieved documents with relevance scores. Higher scores = more relevant. Automatically sorted by relevance.
```

### Prompt Template
```
Pre-built templates for common use cases. Select 'Custom' to provide your own system instructions.
```

### Max Context Length
```
Maximum tokens of context to include. Balance between context richness and prompt size limits.
```

### Validation Rules
```
Custom checks for response quality. Use 'contains' to require keywords, 'not_contains' to forbid terms.
```

### Batch Size
```
Number of items to process together. Larger batches are efficient but use more memory.
```

### Optimization Target
```
What to optimize for: Throughput (speed), Latency (responsiveness), Cost (resource usage), or Accuracy (quality).
```

## Troubleshooting Tips

### Empty Results
```
Check input data is not null/empty. Verify text encoding is UTF-8. Ensure vectors have matching dimensions.
```

### Performance Issues
```
Reduce chunk size or batch size. Enable sentence preservation instead of paragraph. Check optimization metrics.
```

### Poor Similarity Scores
```
Verify vectors are normalized. Check if embedding model matches. Consider adjusting similarity threshold.
```

### Validation Failures
```
Review validation rules specificity. Check if context documents are relevant. Increase max_context_length if needed.
```