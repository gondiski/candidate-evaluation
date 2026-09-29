# Candidate Evaluation Tool

A single-user-per-account tool that runs one hiring evaluation through the manual's nine stages, with three enforced stop gates, and produces two issues of one report: PRE-INTERVIEW (gate sheet blank) and POST-INTERVIEW (gate sheet completed).

## Setup

### Prerequisites

- Ruby 3.3.0
- PostgreSQL 14+
- Redis 7+
- Node.js (for asset compilation)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd candidate-evaluation
```

2. Install dependencies:
```bash
bundle install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Create and migrate the database:
```bash
bundle exec rake db:migrate
bundle exec rake db:seed
```

5. Start the application:
```bash
# Start all services
foreman start

# Or start individually:
bundle exec puma -C config/puma.rb
bundle exec sidekiq -C config/sidekiq.yml
```

### Environment Variables

Create a `.env` file with the following:

```bash
# Database
DATABASE_URL=postgres://localhost:5432/hrmla_development

# Redis
REDIS_URL=redis://localhost:6379/0

# LLM
ANTHROPIC_API_KEY=your_anthropic_api_key_here
ANTHROPIC_MODEL=claude-3-5-sonnet-20241022

# Security
SESSION_SECRET=your_session_secret_here_change_in_production
ENCRYPTION_KEY=your_encryption_key_here_change_in_production

# App
RACK_ENV=development
PORT=9292
```

## Running Sidekiq

Sidekiq is used for background jobs that require LLM calls or report generation:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

Jobs are idempotent and retry-safe. They update StageRun rows for tracking progress.

## Running Tests

### Full Test Suite

```bash
bundle exec rspec
```

### Unit Tests Only

```bash
bundle exec rspec spec/unit
```

### Request Tests Only

```bash
bundle exec rspec spec/request
```

### Feature Tests Only

```bash
bundle exec rspec spec/feature
```

### With Coverage

```bash
COVERAGE=true bundle exec rspec
```

## Architecture

### Nine Stages

1. **Briefing** (Stop Gate) - Capability self-test and briefing acknowledgment
2. **Job Description** - Extract kill criteria and drivers
3. **Weights** (Stop Gate) - Set scoring weights, must sum to 100
4. **Human Gates** - Define human-validated kill factors
5. **CVs** - Score all candidates at once
6. **Verify Employers** (Stop Gate) - Research organizations with web search
7. **Pre-Interview Report** - Generate report with blank gate sheet
8. **Diagnose the Pool** - Assess the advertisement
9. **Final Report** - Enter gate marks, generate post-interview report

### Key Rules

- **Kill First, Score Second** - Kill criteria applied before scoring
- **Two Numbers, Never One** - Weighted score ranks, Floor governs
- **Weights Before Candidates** - Ratified before first CV, closed to argument
- **One Document, Two Issues** - Pre-interview (blank) and post-interview (filled)

### Scoring

- **Scale**: 0-10 integer scores with defined bands
- **Evidence Cap**: Non-evidenced scores capped at 3
- **Floor Rule**: Lowest score among Floor attributes; ≤3 forces reject
- **Verdict**: CLEAR (all YES), ENDED (any NO), OPEN (otherwise)

### Gate Marks

- **YES** - Gate cleared
- **NO** - Gate failed, candidacy ends
- **?** - Tested but not settled
- **NOT_REACHED** - Already ended on earlier line

## Project Structure

```
├── app/
│   ├── controllers/    # Sinatra controllers
│   ├── models/         # Sequel models
│   ├── views/          # ERB templates
│   ├── services/       # Business logic
│   ├── llm/            # LLM client interface
│   ├── jobs/           # Sidekiq workers
│   └── prompts/        # Prompt templates (A-H + Briefing)
├── config/             # Configuration files
├── db/                 # Migrations and seeds
├── spec/               # RSpec tests
└── public/             # Static assets
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the test suite
5. Submit a pull request

## License

This project is proprietary software.
