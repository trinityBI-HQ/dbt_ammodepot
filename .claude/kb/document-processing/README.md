# Document Processing Knowledge Base

> **Last Updated:** 2026-02-06
> **Maintained By:** Claude Code Lab Team

## Overview

Document Processing involves extracting, transforming, and analyzing structured and unstructured data from documents at scale. This category focuses on modern document intelligence using AI/ML, not traditional OCR.

## Philosophy

**Modern document processing is:**
- **Multimodal**: Use vision-capable LLMs (Gemini, GPT-4V) instead of traditional OCR
- **Structured**: Extract to typed schemas (Pydantic) for validation and downstream use
- **Observable**: Track extraction quality, costs, and failures (LangFuse)
- **Scalable**: Event-driven, serverless pipelines for high-volume processing

**Evolution of document processing:**
1. **Traditional OCR** (Tesseract, ABBYY): Text extraction only, layout-blind
2. **Document AI Services** (AWS Textract, Azure Form Recognizer): Layout-aware, but limited to forms
3. **Multimodal LLMs** (Gemini, GPT-4V, Claude Vision): Understand context, handle complex layouts, extract to structured JSON

**Prefer multimodal LLMs when:**
- ✅ Documents have complex layouts (tables, multi-column, handwriting)
- ✅ Need semantic understanding (not just text, but meaning)
- ✅ Need structured extraction (JSON output)
- ✅ Have mixed document types (invoices, receipts, contracts)

**Use traditional OCR when:**
- Document is simple (plain text, single column)
- Cost is primary concern (OCR is cheaper per page)
- No need for semantic understanding

## Technologies

### 📄 Docling

**Path:** [docling/](docling/)

**What it does:** Advanced document parsing and structure extraction for PDFs and other formats.

**When to use:**
- Complex PDF documents with tables, images, and multi-column layouts
- Need to preserve document structure (headings, paragraphs, lists)
- Extracting data for downstream processing (RAG, search, analytics)
- Converting documents to markdown, JSON, or other formats

**Key capabilities:**
- Layout-aware parsing (understands document structure)
- Table extraction and formatting
- Multi-format support (PDF, Word, HTML)
- Metadata extraction (authors, dates, titles)
- Integration with AI/ML pipelines

**Use cases:**
- Research paper parsing for academic databases
- Contract analysis and clause extraction
- Technical documentation processing
- Financial report analysis

### 🤖 Multimodal LLMs (Gemini, GPT-4V, Claude)

**Path:** See [ai-ml/llm-platforms/](../ai-ml/llm-platforms/)

**What it does:** Extract structured data from document images using vision-capable language models.

**When to use:**
- Invoices, receipts, purchase orders
- Forms with handwriting or poor quality scans
- Documents requiring semantic understanding
- Multi-language documents

**Key capabilities:**
- Native image understanding (no OCR pre-processing needed)
- Structured JSON output (Gemini JSON mode)
- Context-aware extraction (understands business rules)
- Multi-page document handling

**Gemini-specific advantages:**
- Affordable pricing ($0.30-1.50 per 1M tokens)
- Native JSON mode (structured output guaranteed)
- Large context windows (up to 2M tokens for multi-page docs)
- Vertex AI integration (enterprise features)

## Document Processing Pipeline

### Modern Architecture (Multimodal LLM)

```
Document Upload (GCS, S3)
  ↓
Cloud Function / Lambda (trigger)
  ↓
Convert to images if needed (TIFF → PNG)
  ↓
Gemini Vision API (extract to JSON)
  ↓
Pydantic validation (type safety)
  ↓
Database (BigQuery, Snowflake)
  ↓
Downstream systems (ERP, analytics, etc.)

Observability:
  - LangFuse traces (latency, cost, errors)
  - Error alerts (Slack, PagerDuty)
  - Quality metrics (extraction accuracy)
```

### Traditional Pipeline (OCR-based)

```
Document Upload
  ↓
Preprocessing (deskew, denoise)
  ↓
OCR (Tesseract, Textract)
  ↓
Text extraction (plain text)
  ↓
Regex / NLP parsing (extract fields)
  ↓
Validation (business rules)
  ↓
Database
```

**Why prefer LLM pipeline:**
- Fewer preprocessing steps (LLMs handle noise, skew, handwriting)
- Higher accuracy (semantic understanding)
- Easier to maintain (no regex hell)
- Handles edge cases better (understands context)

## Document Types

### Invoices

**Complexity:** Medium-High
**Best approach:** Gemini Vision + Pydantic

**Key fields to extract:**
- Invoice number, date, due date
- Vendor information (name, address, tax ID)
- Customer information
- Line items (description, quantity, price)
- Totals (subtotal, tax, total)
- Payment terms

**Challenges:**
- Varying layouts across vendors
- Handwritten notes or stamps
- Multi-page invoices
- Tables with merged cells

**LLM prompt strategy:**
```
Extract invoice data to JSON:
{
  "invoice_number": "...",
  "date": "YYYY-MM-DD",
  "vendor": {"name": "...", "address": "..."},
  "line_items": [{"description": "...", "quantity": 1, "price": 100.00}],
  "total": 100.00
}
```

### Receipts

**Complexity:** Low-Medium
**Best approach:** Gemini Flash (cost-effective)

**Key fields:**
- Merchant name and location
- Date and time
- Line items (simpler than invoices)
- Payment method (cash, card)
- Total amount

**Challenges:**
- Faded thermal paper
- Crumpled or damaged receipts
- Small fonts

### Contracts

**Complexity:** High
**Best approach:** Docling (structure) + Gemini Pro (semantic extraction)

**Key fields:**
- Parties involved
- Effective date and term
- Key clauses (termination, liability, payment terms)
- Signatures and amendments

**Challenges:**
- Long documents (10-100+ pages)
- Legal language (requires semantic understanding)
- Cross-references and definitions

**Strategy:**
1. Use Docling to extract structure (sections, clauses)
2. Use Gemini Pro to extract specific clauses semantically
3. Store in structured database for clause-level search

### Forms

**Complexity:** Low-Medium
**Best approach:** Gemini Flash (if standard forms) or Form Recognizer (Azure)

**Key fields:**
- Checkbox values
- Handwritten text
- Signatures
- Form ID and version

**Challenges:**
- Handwriting recognition
- Checkmarks vs X's
- Multi-select checkboxes

## Decision Frameworks

### Tool Selection: Gemini vs Docling vs Traditional OCR?

| Document Type | Recommended Tool | Why |
|---------------|------------------|-----|
| Invoices | **Gemini Vision** | Structured output, handles variations |
| Receipts | **Gemini Flash** | Cost-effective, fast |
| Contracts | **Docling + Gemini Pro** | Structure + semantic understanding |
| Research papers | **Docling** | Preserve document structure, tables |
| Simple forms | **Gemini Flash** | Quick, accurate |
| Scanned books | **Traditional OCR** | Plain text, volume (cost) |

### Quality vs Cost Trade-off

| Approach | Quality | Cost | Latency | When to Use |
|----------|---------|------|---------|-------------|
| **Gemini Flash** | ⭐⭐⭐⭐ | $ Low | Fast | Standard documents, high volume |
| **Gemini Pro** | ⭐⭐⭐⭐⭐ | $$ Medium | Medium | Complex layouts, handwriting |
| **GPT-4V** | ⭐⭐⭐⭐⭐ | $$$ High | Slow | Highest quality needed |
| **Traditional OCR** | ⭐⭐ | $ Very Low | Fast | Plain text, bulk processing |

### Processing Strategy: Real-time vs Batch?

| Scenario | Recommended Approach | Why |
|----------|---------------------|-----|
| User uploads invoice (needs immediate response) | **Real-time (Cloud Run / Lambda)** | Low latency, user waiting |
| Nightly processing of 1000s of documents | **Batch (Cloud Functions + Pub/Sub)** | Cost-effective, parallel processing |
| Continuous ingestion (10-100/min) | **Streaming (Pub/Sub + workers)** | Scalable, handles spikes |

## Best Practices

### Extraction Accuracy
✅ Use vision-capable LLMs (Gemini, GPT-4V) for complex layouts
✅ Provide examples in prompt (few-shot learning)
✅ Use JSON mode for structured output (Gemini, GPT-4)
✅ Validate with Pydantic (catch errors early)
✅ Implement retry with error feedback (include validation error in retry prompt)

### Cost Optimization
✅ Use Gemini Flash for standard documents (cheaper than Pro)
✅ Resize images to minimum readable resolution (fewer tokens)
✅ Batch process when possible (reduce API overhead)
✅ Cache common extractions (vendor info, product catalogs)
✅ Monitor costs per document type (optimize expensive types)

### Error Handling
✅ Retry failed extractions (with exponential backoff)
✅ Log failures with document metadata (debug later)
✅ Manual review queue for low-confidence extractions
✅ Alert on high error rates (> 5%)
✅ Store raw documents (allow reprocessing)

### Quality Assurance
✅ Sample reviews (manually review 1-5% of extractions)
✅ Confidence scoring (model returns confidence, flag low scores)
✅ Business rule validation (totals add up, dates are valid)
✅ A/B test prompts (compare extraction quality)
✅ Track accuracy metrics over time (monitor degradation)

### Scalability
✅ Event-driven architecture (GCS upload → Pub/Sub → workers)
✅ Horizontal scaling (multiple workers process in parallel)
✅ Rate limiting (respect API limits)
✅ Async processing (don't block user uploads)
✅ Idempotency (safe to retry same document)

## Common Patterns

### Invoice Extraction Pipeline (Production)

```python
# Cloud Function triggered by GCS upload
def process_invoice(event):
    # 1. Download file from GCS
    file_path = download_from_gcs(event['bucket'], event['name'])

    # 2. Convert to image if needed (PDF → PNG)
    image_path = convert_to_image(file_path)

    # 3. Extract with Gemini Vision
    with langfuse.trace(name="invoice_extraction"):
        response = gemini.generate_content(
            [image_path, EXTRACTION_PROMPT],
            generation_config={"response_mime_type": "application/json"}
        )

    # 4. Validate with Pydantic
    try:
        invoice = Invoice(**json.loads(response.text))
    except ValidationError as e:
        # Retry with error feedback
        response = gemini.generate_content(
            [image_path, f"{EXTRACTION_PROMPT}\n\nPrevious attempt failed: {e}"]
        )
        invoice = Invoice(**json.loads(response.text))

    # 5. Write to BigQuery
    bigquery_client.insert_rows(INVOICE_TABLE, [invoice.dict()])

    # 6. Archive processed file
    move_to_processed(event['bucket'], event['name'])
```

### Document Classification

```
Document Upload
  ↓
Gemini classification (invoice, receipt, contract, other)
  ↓
Route to specialized extraction workflow
  ↓
Invoice → Invoice extractor
Receipt → Receipt extractor
Contract → Contract analyzer
Other → Manual review queue
```

### Multi-Page Document Handling

```python
# For documents > 10 pages, process in chunks
def process_large_document(pdf_path):
    pages = split_pdf(pdf_path)  # Split into individual pages

    # Process pages in parallel
    with ThreadPoolExecutor(max_workers=10) as executor:
        results = executor.map(extract_page, pages)

    # Combine results
    combined = combine_extractions(results)

    return combined
```

## Integration Patterns

### Gemini + LangFuse + Pydantic + BigQuery

Full observability and validation pipeline (see AI/ML README for code example).

### Docling + RAG (Retrieval-Augmented Generation)

```
PDF Documents
  ↓
Docling (extract structure + text)
  ↓
Chunk and embed (OpenAI embeddings)
  ↓
Store in vector DB (Pinecone, Weaviate)
  ↓
User query → Retrieve relevant chunks → LLM generates answer
```

**Use case:** Q&A over large document corpus (contracts, manuals, research papers)

### n8n + Gemini + Airtable

Low-code document processing workflow:
```
n8n webhook (document uploaded)
  ↓
Download file
  ↓
HTTP request to Gemini API
  ↓
Parse JSON response
  ↓
Insert into Airtable
  ↓
Slack notification
```

## Anti-Patterns

❌ **Regex parsing of OCR text**: Brittle, hard to maintain → Use LLM extraction
❌ **No validation**: Trust LLM output blindly → Use Pydantic validation
❌ **Single LLM call without retries**: Fails on rate limits → Retry with backoff
❌ **Ignoring cost**: High-end model for all documents → Use Gemini Flash for standard docs
❌ **No observability**: Can't debug extraction failures → Use LangFuse tracing
❌ **Synchronous processing**: User waits 10s for extraction → Async processing
❌ **No quality monitoring**: Accuracy degrades over time → Sample reviews, track metrics

## Related Knowledge

- **AI/ML**: See [ai-ml/llm-platforms/gemini/](../ai-ml/llm-platforms/gemini/) for vision extraction
- **AI/ML**: See [ai-ml/validation/pydantic/](../ai-ml/validation/pydantic/) for structured validation
- **AI/ML**: See [ai-ml/observability/langfuse/](../ai-ml/observability/langfuse/) for LLM observability
- **Cloud**: See [cloud/gcp/](../cloud/gcp/) for serverless deployment (Cloud Run, Cloud Functions)
- **Automation**: See [automation/workflow-automation/n8n/](../automation/workflow-automation/n8n/) for low-code pipelines

## Agents

Specialized agents for document processing:
- `/extraction-specialist` - Invoice and document extraction with Gemini Vision
- `/function-developer` - GCP Cloud Run functions for document pipelines

---

**Use multimodal LLMs • Validate with Pydantic • Monitor extraction quality**
