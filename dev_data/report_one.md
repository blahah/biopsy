de-novo transcriptome assembly development report
=================================================

## 1: k-sweep in SOAPDenovoTrans with varying read depth

Reads were subsampled at 1, 2, 4, 8, and 16 x 100k pairs from trimmed, normalised, paired 100bp rice Illumina reads.
Assemblies were performed using default settings for SOAPDenovoTrans (soapdt) with varying values of *k* from 21-86 with step 4.
All calculations were run on a 24-core Intel i7 node with 100GB RAM and with files stored in tmpfs (ramdisk) for speed.

### Assembly time scales approximately linearly with read sample size

Notably, the full k-sweep with 100k reads took only around one minute.
![plot of chunk unnamed-chunk-1](figure/unnamed-chunk-1.png) 


### Three objective functions

Three objective functions were used to analyse each assembly:
* _brm_ : bad read mappings
* _rba_ : conditional annotation
* _ut_: unexpressed transcripts

![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-21.png) ![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-22.png) ![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-23.png) ![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-24.png) ![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-25.png) ![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-26.png) ![plot of chunk unnamed-chunk-2](figure/unnamed-chunk-27.png) 


### Dimension-reduction of the three objective functions
![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-31.png) ![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-32.png) ![plot of chunk unnamed-chunk-3](figure/unnamed-chunk-33.png) 


