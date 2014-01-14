biopsy
==========

An automatic optimisation framework for programs and pipelines.

Biopsy is a framework for optimising any program or pipeline which produces a measurable output. By reducing the settings of one or more programs to a parameter space, and by carefully choosing objective functions with which to measure the output of the program(s), biopsy can use a range of optimisation strategies to rapidly find the settings that perform the best. Combined with a strategy for subsampling the input data, this can lead to vast time and performance improvements.

A simple example of the power of this approach is *de-novo* transcriptome assembly. Typically, the assembly process takes many GB of data as input, uses many GB of RAM and takes many hours to complete. This prevents researchers from performing full parameter sweeps, and they are therefore forced to use word-of-mouth and very basic optimisation to choose assembler settings. [Assemblotron](https://github.com/Blahah/assemblotron), which uses the Biopsy framework, can fully optimise any *de-novo* assembler to produce the optimal assembly possible given a particular input. This typically takes little more time than running a single assembly.

## Installation

Make sure you have Ruby installed, then:

`gem install biopsy --pre`

## Usage

Detailed usage instructions are on the wiki. Here's a quick overview:

1. Define your optimisation target. This is a program or pipeline you want to optimise, and you define it by filling in a template [YAML file](http://en.wikipedia.org/wiki/YAML). Easy!
2. Define your objective function. This is a program that analyses the output of your program and gives it a score. You define it by writing a small amount of Ruby code. Don't worry - there's a template and detailed instructions on the wiki.
3. Run Biopsy, and wait while the experiment runs.

### Command line examples

`biopsy list targets`
`biopsy list objectives`
`biposy run --target test_target --objective test_objective --input test_file.txt --time-limit 24h`

## Development status

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

This project is in alpha development and is not yet ready for deployment. 
Please don't report issues or request documentation until we are ready for beta release (see below for estimated timeframe).

### Roadmap

| Class            | Code   | Tests   | Docs   |
| ------------     | :----: | ------: | -----: |
| Settings         | DONE   | DONE    | DONE   |
| Target           | DONE   | DONE    | DONE   |
| Domain           | DONE   | DONE    | DONE   |
| Experiment       | DONE   | DONE    | DONE   |
| TabuSearch       | DONE   | -       | -      |
| ParameterSweeper | DONE   | -       | -      |
| ObjectiveHandler | DONE   | DONE    | DONE   |

* ~ 20/24 tasks completed, ~83% done overall
* alpha released: 6th September 2013
* planned beta release date: 17th November 2013

### Documentation

Documentation is in development and will be released with the beta.

### Citation

This is *pre-release*, *pre-publication* academic software. In lieu of a paper to cite, please cite this Github repo and/or the [Figshare DOI (http://dx.doi.org/10.6084/m9.figshare.790660
)](http://dx.doi.org/10.6084/m9.figshare.790660) if your use of the software leads to a publication.

[![Analytics](https://ga-beacon.appspot.com/UA-46900280-1/Blahah/biopsy)](https://github.com/Blahah/biopsy)
