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

## 