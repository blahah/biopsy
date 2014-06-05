biopsy
==========

[![Gem Version](https://badge.fury.io/rb/biopsy.png)][gem]
[![Build Status](https://secure.travis-ci.org/Blahah/biopsy.png?branch=master)][travis]
[![Dependency Status](https://gemnasium.com/Blahah/biopsy.png?travis)][gemnasium]
[![Code Climate](https://codeclimate.com/github/Blahah/biopsy.png)][codeclimate]
[![Coverage Status](https://coveralls.io/repos/Blahah/biopsy/badge.png?branch=master)][coveralls]

[gem]: https://badge.fury.io/rb/biopsy
[travis]: https://travis-ci.org/Blahah/biopsy
[gemnasium]: https://gemnasium.com/Blahah/biopsy
[codeclimate]: https://codeclimate.com/github/Blahah/biopsy
[coveralls]: https://coveralls.io/r/Blahah/biopsy

An automatic optimisation framework for programs and pipelines.

Biopsy is a framework for optimising the settings of any program or pipeline which produces a measurable output. It is particularly intended for bioinformatics, where computational pipelines take a long time to run, making optimisation of parameters using crude methods unfeasible. Biopsy will use a range of discrete optimisation strategies to rapidly find the settings that perform the best.

It can handle parameter spaces of any size: if it is possible to try every parameter combination in the time you have available, Biopsy will do this. However, Biopsy really shines when handling large numbers of parameter combinations.

## Development status

This project is in early development and is not yet ready for deployment.
Please don't report issues or request documentation until we are ready for release. If you have a burning desire to use biopsy, get in touch: rds45@cam.ac.uk.

## Installation

Make sure you have Ruby installed, then:

`gem install biopsy`

## Usage

Detailed usage instructions are on the wiki. Here's a quick overview:

1. Define your optimisation target. This is a program or pipeline you want to optimise, and you define it by filling in a template YAML file and wrapping your program in a tiny Ruby launcher.
2. Define your objective function. This is a program that analyses the output of your program and gives it a score. You define it by writing a small amount of Ruby code. Don't worry - there's a template and detailed instructions on the wiki.
3. Run Biopsy, and wait while the experiment runs. Maybe grab a cup of tea, read some [hacker news](http://news.ycombinator.com).
4. Bask in the brilliance of your new optimal settings.

### Command line examples

`biopsy list targets`
`biopsy list objectives`
`biposy run --target test_target --objective test_objective --input test_file.txt --time-limit 24h`

### Optimisation algorithms

Biopsy currently implements 3 optimisation algorithms.

1. Parameter Sweeper - a simple combinatorial parameter sweep, with optional subsampling of the parameter space
2. Tabu Search - a local search with a long memory that takes the consensus of multiple searchers
3. SPEA2 - a high performance general-purpose genetic algorithm

### Documentation

Documentation is in development and will be released with the beta.

### Citation

This is *pre-release*, *pre-publication* academic software. In lieu of a paper to cite, please cite this Github repo and/or the [Figshare DOI (http://dx.doi.org/10.6084/m9.figshare.790660
)](http://dx.doi.org/10.6084/m9.figshare.790660) if your use of the software leads to a publication.

[![Analytics](https://ga-beacon.appspot.com/UA-46900280-1/Blahah/biopsy)](https://github.com/Blahah/biopsy)

### Software using Biopsy

- [Assemblotron](https://github.com/Blahah/assemblotron) can fully optimise any *de-novo* transcriptome assembler to produce the optimal assembly possible given a particular input. This typically takes little more time than running a single assembly.
