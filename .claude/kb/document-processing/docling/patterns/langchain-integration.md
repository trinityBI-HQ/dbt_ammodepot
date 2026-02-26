# LangChain Integration

> **Purpose**: Integrate Docling with LangChain for RAG pipelines, document loaders, and GenAI workflows
> **MCP Validated**: 2026-02-06

## When to Use

- Building RAG (Retrieval Augmented Generation) systems
- Creating document Q&A applications
- Ingesting documents into vector databases
- Building knowledge base search systems
- Integrating with LangChain agents

## Implementation

```python
from langchain_community.document_loaders import DoclingLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain.chains import RetrievalQA
from typing import List
from pathlib import Path


class DoclingRAGPipeline:
    """RAG pipeline using Docling for document processing."""

    def __init__(
        self,
        embedding_model: str = "text-embedding-3-small",
        llm_model: str = "gpt-4",
        chunk_size: int = 1000,
        chunk_overlap: int = 200
    ):
        """
        Initialize RAG pipeline.

        Args:
            embedding_model: OpenAI embedding model
            llm_model: LLM for question answering
            chunk_size: Text chunk size
            chunk_overlap: Overlap between chunks
        """
        self.embeddings = OpenAIEmbeddings(model=embedding_model)
        self.llm = ChatOpenAI(model=llm_model, temperature=0)
        self.text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=chunk_size,
            chunk_overlap=chunk_overlap,
            separators=["\n\n", "\n", " ", ""]
        )
        self.vectorstore = None

    def load_documents(self, file_paths: List[str]) -> List:
        """
        Load documents using Docling.

        Args:
            file_paths: List of document paths

        Returns:
            List of LangChain Document objects
        """
        all_documents = []

        for file_path in file_paths:
            # Use DoclingLoader for each file
            loader = DoclingLoader(file_path)
            documents = loader.load()
            all_documents.extend(documents)

        return all_documents

    def create_vectorstore(self, documents: List, persist_directory: str = None):
        """
        Create vector store from documents.

        Args:
            documents: LangChain documents
            persist_directory: Optional directory to persist vectorstore
        """
        # Split documents into chunks
        texts = self.text_splitter.split_documents(documents)

        # Create vector store
        self.vectorstore = Chroma.from_documents(
            documents=texts,
            embedding=self.embeddings,
            persist_directory=persist_directory
        )

        return self.vectorstore

    def create_qa_chain(self):
        """Create question-answering chain."""
        if self.vectorstore is None:
            raise ValueError("Vectorstore not created. Call create_vectorstore first.")

        retriever = self.vectorstore.as_retriever(
            search_type="similarity",
            search_kwargs={"k": 4}
        )

        qa_chain = RetrievalQA.from_chain_type(
            llm=self.llm,
            chain_type="stuff",
            retriever=retriever,
            return_source_documents=True
        )

        return qa_chain

    def query(self, question: str):
        """
        Query the knowledge base.

        Args:
            question: User question

        Returns:
            Answer and source documents
        """
        qa_chain = self.create_qa_chain()
        result = qa_chain({"query": question})

        return {
            "answer": result["result"],
            "sources": [doc.metadata for doc in result["source_documents"]]
        }


def build_rag_system(document_directory: str, persist_directory: str = "./chroma_db"):
    """Build complete RAG system from document directory."""
    pipeline = DoclingRAGPipeline()
    doc_dir = Path(document_directory)
    file_paths = [str(f) for f in doc_dir.glob("*.pdf")]
    documents = pipeline.load_documents(file_paths)
    pipeline.create_vectorstore(documents, persist_directory)
    return pipeline


def simple_document_qa(pdf_path: str, question: str) -> str:
    """Simple QA on single document."""
    loader = DoclingLoader(pdf_path)
    documents = loader.load()
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    texts = text_splitter.split_documents(documents)
    vectorstore = Chroma.from_documents(texts, OpenAIEmbeddings())
    qa = RetrievalQA.from_chain_type(
        llm=ChatOpenAI(model="gpt-4", temperature=0),
        retriever=vectorstore.as_retriever()
    )
    return qa({"query": question})["result"]
```

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `embedding_model` | `"text-embedding-3-small"` | OpenAI embedding model |
| `llm_model` | `"gpt-4"` | LLM for answers |
| `chunk_size` | `1000` | Characters per chunk |
| `chunk_overlap` | `200` | Overlap between chunks |

## Example Usage

```python
# Simple document Q&A
answer = simple_document_qa("manual.pdf", "What are the requirements?")

# Build full RAG system
pipeline = build_rag_system("./documents", "./vectordb")
result = pipeline.query("What are the key findings?")
print(f"Answer: {result['answer']}")

# Using DoclingLoader
from langchain_community.document_loaders import DoclingLoader
loader = DoclingLoader("document.pdf")
documents = loader.load()
```

## See Also

- [concepts/export-formats.md](../concepts/export-formats.md) - Markdown export for RAG
- [patterns/batch-processing.md](batch-processing.md) - Process document collections
- [concepts/docling-document.md](../concepts/docling-document.md) - Document structure
