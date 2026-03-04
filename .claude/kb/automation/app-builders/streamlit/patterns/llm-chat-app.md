# LLM Chat App Pattern

> **Purpose**: Build conversational AI interfaces with st.chat_message, st.chat_input, and streaming
> **MCP Validated**: 2026-03-03

## When to Use

- Building chatbots powered by OpenAI, Anthropic, or other LLM APIs
- Creating conversational data exploration tools
- Building internal Q&A bots over company data
- Prototyping AI assistants with streaming responses

## Implementation

```python
import streamlit as st
from openai import OpenAI

st.title("AI Chat Assistant")

# Initialize OpenAI client (cached as singleton)
@st.cache_resource
def get_client():
    return OpenAI(api_key=st.secrets["openai_key"])

client = get_client()

# Initialize conversation history
if "messages" not in st.session_state:
    st.session_state.messages = [
        {"role": "system", "content": "You are a helpful data analyst assistant."}
    ]

# Display conversation history
for msg in st.session_state.messages:
    if msg["role"] != "system":
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

# Handle user input
if prompt := st.chat_input("Ask me anything about your data"):
    # Add user message to history
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # Generate and stream assistant response
    with st.chat_message("assistant"):
        stream = client.chat.completions.create(
            model="gpt-4o",
            messages=st.session_state.messages,
            stream=True,
        )
        response = st.write_stream(stream)

    # Add assistant response to history
    st.session_state.messages.append({"role": "assistant", "content": response})
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `st.chat_message(name)` | Required | `"user"`, `"assistant"`, `"ai"`, `"human"`, or custom |
| `avatar` | Auto | Emoji, image URL, or `":material/icon:"` |
| `st.chat_input(placeholder)` | Required | Placeholder text in input box |
| `st.chat_input(accept_file)` | `False` | Allow file attachments (1.43+) |
| `st.write_stream(stream)` | Required | Generator or OpenAI stream object |

## Chat with File Upload (1.43+)

```python
if prompt := st.chat_input("Ask about a document", accept_file=True):
    # prompt.text contains the message
    # prompt.files contains uploaded files
    if prompt.files:
        for f in prompt.files:
            content = f.read().decode("utf-8")
            st.session_state.context = content

    user_text = prompt.text or "Analyze the uploaded file"
    process_message(user_text)
```

## Chat with Audio Input (1.52+)

```python
if prompt := st.chat_input("Speak or type", accept_audio=True):
    if prompt.audio:
        # Process audio input (e.g., with Whisper)
        transcript = transcribe(prompt.audio)
        process_message(transcript)
    elif prompt.text:
        process_message(prompt.text)
```

## Streaming with Status Indicators

```python
with st.chat_message("assistant"):
    # Show status while processing
    with st.status("Thinking...", expanded=False) as status:
        # Step 1: Search knowledge base
        st.write("Searching knowledge base...")
        results = search_kb(prompt)

        # Step 2: Generate response
        st.write("Generating response...")
        response = generate_response(prompt, results)

        status.update(label="Complete!", state="complete")

    # Display final response
    st.markdown(response)
```

## Custom Streaming Generator

```python
import time

def response_generator(prompt: str):
    """Custom generator for streaming responses."""
    response = call_llm(prompt)
    for word in response.split():
        yield word + " "
        time.sleep(0.05)

# Display with typewriter effect
with st.chat_message("assistant"):
    response = st.write_stream(response_generator(prompt))
```

## Conversation Management

```python
# Clear conversation
if st.sidebar.button("New Chat"):
    st.session_state.messages = [
        {"role": "system", "content": "You are a helpful assistant."}
    ]
    st.rerun()

# Export conversation
if st.sidebar.download_button(
    "Export Chat",
    data=json.dumps(st.session_state.messages, indent=2),
    file_name="chat_history.json",
    mime="application/json",
):
    st.sidebar.success("Exported!")

# Model selection
model = st.sidebar.selectbox(
    "Model",
    ["gpt-4o", "gpt-4o-mini", "gpt-3.5-turbo"],
    key="model_select",
)
```

## Chat Message Avatars

```python
# Built-in avatars
with st.chat_message("user"):       # default user icon
    st.write("Hello")

with st.chat_message("assistant"):  # default bot icon
    st.write("Hi there!")

# Custom avatars
with st.chat_message("user", avatar=":material/person:"):
    st.write("Material icon avatar")

with st.chat_message("assistant", avatar="https://example.com/bot.png"):
    st.write("Image URL avatar")
```

## See Also

- [State Management](../concepts/state-management.md)
- [Caching](../concepts/caching.md)
- [Database Integration](../patterns/database-integration.md)
