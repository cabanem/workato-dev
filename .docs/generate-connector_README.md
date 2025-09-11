# Connector Generator
## The idea
1. Blueprint &rarr; Ruby
    - Define a YAML/JSON blueprint (title, connection, actions, schemas, methods, picklists, etc)
    - The generator parses the blueprint and emits a `connector.rb` that adheres to the Workato SDK's structure:
        - `connection`
        - `test`
        - `actions`
        - `object_definitions`
        - `pick_lists`
        - `methods`
    - **Hypothesis**: 
        - We can use structured input to generate a Workato Ruby adapter.
        - Why this will work:
            - The SDK's schema format is an array of field hashes
                - Actions are composed of `input_fields`/`output_fields` lambdas
                - The `execute` block is Ruby;
                - `pick_lists` are lambdas, and we can attach arbitrary helper `methods` as needed. 
            - We can use a structured 'blueprint' to realize these constructs programatically.
2. Validate locally
    - We will use `workato exec` to run `input_fields`/`output_fields`/`execute` (or entire action)
    - Alternatively, build Workato schema from sample JSON/CSV with `workato generate schema`
3. Publish
    - From the CLI `workato push`
    - Programatically create/update/realease via the Developer API (`/api/custom_connectors`, `/api/custom_connectors/:id`, `/api/custom_connectors/:id/release`)

## Components
1. Blueprint format (YAML)
The following example demonstrates the structure and format structured input should take. 

```yaml
# blueprint.yaml
meta:
  key: rag_utilities
  title: "RAG Utilities"
  description: "Custom utility functions for internal automations"
  version: "1.0.0"
  help: "Toolkit for text ops, similarity, and batch utilities."

connection:
  fields:
    - name: environment
      label: Environment
      control_type: select
      options:
        - [Development, dev]
        - [Staging, staging]
        - [Production, prod]
      optional: true
    - name: chunk_size_default
      type: integer
      control_type: integer
      default: 1000
      optional: true
    - name: chunk_overlap_default
      type: integer
      control_type: integer
      default: 100
      optional: true
    - name: similarity_threshold
      type: number
      control_type: number
      default: 0.7
      optional: true
  authorization:
    type: custom_auth              # inert auth to satisfy SDK
    headers:
      X-Environment: "{{connection.environment}}"
test:
  static_output:
    status: "connected"

pick_lists:
  similarity_types:
    static:
      - ["Cosine Similarity", "cosine"]
      - ["Euclidean Distance", "euclidean"]
      - ["Dot Product", "dot_product"]

object_definitions:
  chunk_object:
    fields:
      - { name: chunk_id, type: string }
      - { name: chunk_index, type: integer }
      - { name: text, type: string }
      - { name: token_count, type: integer }
      - { name: start_char, type: integer }
      - { name: end_char, type: integer }
      - { name: metadata, type: object }

actions:
  - key: smart_chunk_text
    title: "Smart Chunk Text"
    description: "Split text into overlapping chunks"
    input_schema:
      - { name: text, type: string, control_type: text-area, optional: false }
      - { name: chunk_size, type: integer, default: 1000, optional: true }
      - { name: chunk_overlap, type: integer, default: 100, optional: true }
      - { name: preserve_sentences, type: boolean, default: true, optional: true }
      - { name: preserve_paragraphs, type: boolean, default: false, optional: true }
    output_schema:
      - name: chunks
        type: array
        of: object
        properties_ref: chunk_object
      - { name: total_chunks, type: integer }
      - { name: total_tokens, type: integer }
    execute:
      type: method_call
      name: chunk_text_with_overlap
      args: ["input"]     # will render as call(:chunk_text_with_overlap, input)

  - key: calculate_similarity
    title: "Calculate Vector Similarity"
    description: "Cosine/Euclidean/Dot"
    input_schema:
      - { name: vector_a, type: array, of: number, optional: false }
      - { name: vector_b, type: array, of: number, optional: false }
      - { name: similarity_type, type: string, control_type: select, pick_list: similarity_types, default: cosine, optional: true }
      - { name: normalize, type: boolean, default: true, optional: true }
    output_schema:
      - { name: similarity_score, type: number }
      - { name: similarity_percentage, type: number }
      - { name: is_similar, type: boolean }
      - { name: similarity_type, type: string }
      - { name: computation_time_ms, type: integer }
    execute:
      type: method_call
      name: compute_similarity
      args: ["input", "connection"]

methods:
  chunk_text_with_overlap: |
    text = input["text"].to_s
    cs = (input["chunk_size"] || 1000).to_i
    ov = (input["chunk_overlap"] || 100).to_i
    keep_sent  = !!input["preserve_sentences"]
    keep_para  = !!input["preserve_paragraphs"]
    chars_per_chunk = [cs, 1].max * 4
    char_overlap    = [[ov, 0].max, cs].min * 4
    chunks = []; i=0; pos=0
    while pos < text.length
      tentative_end = [pos + chars_per_chunk, text.length].min
      chunk_end = tentative_end
      if keep_para && tentative_end < text.length
        rel = text[pos...tentative_end].rindex(/\n{2,}/); chunk_end = pos + rel + 1 if rel
      end
      if keep_sent && chunk_end == tentative_end && tentative_end < text.length
        rel = text[pos...tentative_end].rindex(/[.!?]["')\]]?\s/); chunk_end = pos + rel + 1 if rel
      end
      chunk_end = tentative_end if chunk_end <= pos
      t = text[pos...chunk_end]
      chunks << { chunk_id: "chunk_#{i}", chunk_index: i, text: t,
        token_count: (t.length/4.0).ceil, start_char: pos, end_char: chunk_end,
        metadata: { has_overlap: i>0, is_final: chunk_end >= text.length } }
      break if chunk_end >= text.length
      pos = [chunk_end - char_overlap, 0].max; i += 1
    end
    { chunks: chunks, total_chunks: chunks.length, total_tokens: chunks.sum { |c| c[:token_count] } }

  compute_similarity: |
    start = Time.now
    a = Array(input["vector_a"]||[])
    b = Array(input["vector_b"]||[])
    raise "Both vectors required" if a.empty? || b.empty?
    raise "Vectors must be the same length" unless a.length == b.length
    normalize = input.key?("normalize") ? !!input["normalize"] : true
    type = (input["similarity_type"] || "cosine").to_s
    threshold = (connection["similarity_threshold"] || 0.7).to_f
    if normalize
      mag = Math.sqrt(a.sum { |x| x*x }); a = a.map { |x| mag.zero? ? 0.0 : x/mag }
      mag = Math.sqrt(b.sum { |x| x*x }); b = b.map { |x| mag.zero? ? 0.0 : x/mag }
    end
    dot = a.zip(b).sum { |x,y| x*y }
    ma = Math.sqrt(a.sum { |x| x*x }); mb = Math.sqrt(b.sum { |x| x*x })
    score = case type
      when "cosine" then (ma>0 && mb>0) ? dot/(ma*mb) : 0.0
      when "euclidean" then d=Math.sqrt(a.zip(b).sum { |x,y| (x-y)**2 }); 1.0/(1.0+d)
      when "dot_product" then dot
      else (ma>0 && mb>0) ? dot/(ma*mb) : 0.0
    end
    percent = %w[cosine euclidean].include?(type) ? (score*100).round(2) : nil
    { similarity_score: score.round(6), similarity_percentage: percent,
      is_similar: score >= threshold, similarity_type: type,
      computation_time_ms: ((Time.now-start)*1000).round }
```

2. Generator code (blueprint &rarr; `connector.rb`)
Place the code below in `wkgen_from_blueprint.rb`.
    - About
        - supports local file or HTTPS URL
        - handles `properties_ref` to reuse `object_definitions` in schemas
        - `method_call` reuses a named method from the `methods` block
    - Functionality
        - Reads the blueprint (file or HTTPS URL), expands `properties_ref` and prints a valid `connector.rb`
        - Keeps `authorization: custom_auth` inert (SDK-legal per docs)
        - Produces Workato schema exactly as the docs require
        - Developer can select between `execute: method call` (recommended) or `inline_ruby` (if you must inject code)

```ruby
#!/usr/bin/env ruby
# wkgen_from_blueprint.rb
require 'yaml'
require 'json'
require 'erb'
require 'uri'
require 'net/http'
require 'fileutils'

def fetch_blueprint(src)
  if src =~ /\Ahttps?:/i
    uri = URI(src)
    raise "Only HTTPS allowed" unless uri.scheme == 'https'
    resp = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.read_timeout = 20
      http.get(uri.request_uri, { 'Accept' => 'application/yaml, application/json, text/plain' })
    end
    raise "HTTP #{resp.code}" unless resp.code.to_i.between?(200,299)
    body = resp.body
  else
    body = File.read(src)
  end
  case File.extname(src)
  when '.yaml','.yml','' then YAML.safe_load(body, permitted_classes: [], aliases: true) || {}
  when '.json'           then JSON.parse(body)
  else
    YAML.safe_load(body, permitted_classes: [], aliases: true) || {}
  end
end

def to_ruby(obj)
  case obj
  when Hash
    '{ ' + obj.map { |k,v| "#{k.to_s.to_sym}: #{to_ruby(v)}" }.join(', ') + ' }'
  when Array
    '[ ' + obj.map { |e| to_ruby(e) }.join(', ') + ' ]'
  when String
    obj.inspect
  when Numeric, TrueClass, FalseClass, NilClass
    obj.inspect
  else
    raise "Unsupported in blueprint -> #{obj.class}"
  end
end

def schema_to_ruby(schema, obj_defs)
  # expand properties_ref
  expanded = (schema || []).map do |f|
    if f.is_a?(Hash) && f['properties_ref']
      ref = f['properties_ref']
      props = (obj_defs.dig(ref, 'fields') || [])
      h = f.dup
      h.delete('properties_ref')
      h['properties'] = props
      h
    else
      f
    end
  end
  to_ruby(expanded)
end

def build_actions(actions, obj_defs)
  (actions || []).map do |a|
    exec = a.fetch('execute', {})
    exec_code =
      case exec['type']
      when 'method_call'
        name = exec['name'] or raise "execute.name required"
        args = (exec['args'] || ['input']).join(', ')
        "call(:#{name}, #{args})"
      when 'inline_ruby'
        exec['code'] or raise "execute.code required"
      else
        # pass-through: just echo inputs for debugging
        "input"
      end
    <<~RUBY
      #{a['key']}: {
        title: #{(a['title'] || a['key']).inspect},
        description: #{(a['description'] || '').inspect},

        input_fields: lambda do
          #{schema_to_ruby(a['input_schema'], obj_defs)}
        end,

        output_fields: lambda do
          #{schema_to_ruby(a['output_schema'], obj_defs)}
        end,

        execute: lambda do |connection, input, extended_input_schema, extended_output_schema|
          #{exec_code}
        end
      }
    RUBY
  end.join(",\n")
end

def build_picklists(pick_lists)
  return '' if pick_lists.nil? || pick_lists.empty?
  inner = pick_lists.map do |name, spec|
    if spec['static']
      arr = to_ruby(spec['static'])
      <<~RUBY
        #{name}: lambda do
          #{arr}
        end
      RUBY
    elsif code = spec['inline_ruby']
      <<~RUBY
        #{name}: lambda do |args|
          #{code}
        end
      RUBY
    else
      raise "pick_list #{name} must be 'static' or 'inline_ruby'"
    end
  end.join(",\n")

  "pick_lists: {\n#{inner}\n}"
end

def build_methods(methods_hash)
  return "methods: { }" if methods_hash.nil? || methods_hash.empty?
  inner = methods_hash.map do |name, code|
    <<~RUBY
      #{name}: lambda do |*args|
        input = args[0].is_a?(Hash) ? args[0] : (defined?(input) ? input : {})
        connection = args[1].is_a?(Hash) ? args[1] : (defined?(connection) ? connection : {})
        #{code}
      end
    RUBY
  end.join(",\n")
  "methods: {\n#{inner}\n}"
end

def build_object_definitions(obj_defs)
  return '' if obj_defs.nil? || obj_defs.empty?
  inner = obj_defs.map do |name, spec|
    fields = to_ruby(spec['fields'] || [])
    <<~RUBY
      #{name}: {
        fields: lambda do
          #{fields}
        end
      }
    RUBY
  end.join(",\n")
  "object_definitions: {\n#{inner}\n}"
end

def build_connection(conn)
  fields = to_ruby(conn['fields'] || [])
  auth = conn['authorization'] || { 'type' => 'custom_auth' }
  auth_ruby =
    if auth['type'] == 'custom_auth'
      # Simple header mapper from template strings
      if auth['headers']&.any?
        header_lines = auth['headers'].map do |k,v|
          v_ruby = v.to_s.gsub('{{connection.', 'connection["').gsub('}}','"]').inspect # simple {{connection.field}} -> connection["field"]
          "#{k.inspect} => eval(#{v_ruby})"
        end.join(', ')
        <<~RUBY
          authorization: {
            type: "custom_auth",
            apply: lambda do |connection|
              headers(#{header_lines})
            end
          }
        RUBY
      else
        <<~RUBY
          authorization: {
            type: "custom_auth",
            apply: lambda do |_connection| end
          }
        RUBY
      end
    else
      # Extend here if you ever want OAuth/basic/etc.
      'authorization: { type: "custom_auth", apply: lambda { |_c| } }'
    end

  <<~RUBY
    connection: {
      fields: #{fields},
      #{auth_ruby.strip}
    }
  RUBY
end

def build_test(test_spec)
  if test_spec && test_spec['static_output']
    out = to_ruby(test_spec['static_output'])
    "test: lambda do |connection| #{out} end"
  else
    'test: lambda do |_connection| { status: "connected" } end'
  end
end

def render_connector(bp)
  meta = bp['meta'] || {}
  conn = build_connection(bp['connection'] || {})
  test = build_test(bp['test'] || {})
  obj_defs = bp['object_definitions'] || {}
  actions = build_actions(bp['actions'] || [], obj_defs)
  methods = build_methods(bp['methods'] || {})
  picklists = build_picklists(bp['pick_lists'] || {})

  <<~RUBY
  {
    title: #{(meta['title'] || 'Custom Connector').inspect},
    description: #{(meta['description'] || '').inspect},
    version: #{(meta['version'] || '1.0.0').inspect},
    help: ->() { #{(meta['help'] || '').inspect} },

    #{conn.strip},

    #{test},

    actions: {
      #{actions}
    },

    #{methods},

    #{build_object_definitions(obj_defs)},

    #{picklists}
  }
  RUBY
end

# --- main ---
src = ARGV[0] or abort("Usage: ruby wkgen_from_blueprint.rb <blueprint.{yml|yaml|json}|https-url> [out_dir]")
out_dir = ARGV[1] || './out'
bp = fetch_blueprint(src)
code = render_connector(bp)
key = (bp.dig('meta','key') || 'generated_connector').gsub(/[^\w]/,'_')
target = File.join(out_dir, key)
FileUtils.mkdir_p(target)
File.write(File.join(target, 'connector.rb'), code)
File.write(File.join(target, 'README.md'), (bp.dig('meta','description') || ''))
puts "Wrote #{target}/connector.rb"
```

3. Run, validate, iterate
You'll find CLI references for running `input_fields`, `output_fields`, actions below. You can also pass `--config-fields`, `--extended-input-schema`, etc when testing dynamic behavior.

```bash
# 1) Generate Ruby from blueprint
ruby wkgen_from_blueprint.rb ./blueprint.yaml ./out

# 2) Inspect the file
bat ./out/rag_utilities/connector.rb  # or cat/less

# 3) Dry-run with the SDK CLI
workato exec test --connector ./out/rag_utilities/connector.rb --verbose

# 4) Run an action end-to-end
echo '{"text":"Hello world\n\nTwo paragraphs."}' > /tmp/in.json
workato exec actions.smart_chunk_text --connector ./out/rag_utilities/connector.rb --input /tmp/in.json --verbose
```

**Optional**
If you have sample JSON payloads, generate their schema automatically, and past the JSON array into your blueprint's `input_schema`/`output_schema`.
```bash
workato generate schema --api-token $WORKATO_API_TOKEN --json ./sample.json > /tmp/schema.json
```

## Important considerations
- Validate schema before rendering
    - required keys (name, type)
    - correct `of/properties` pairs
    - keep to supported control types
- Keep inline Ruby behind a flag and prefer `method_call`
    - code lives in `methods` block and is more testable
- Security
    - limit remote blueprint fetches to HTTPS
    - set size caps
    - for provenance, pin by SHA256
- For dyanmic fields, the SDK supports `config_fields`, `extends_schema`, and `convert_input`/`convert_output`
    - consider exposing these later