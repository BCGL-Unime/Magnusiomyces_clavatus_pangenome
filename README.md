# "Genomic Epidemiology and Phylogenomics of _Magnusiomyces clavatus_: A Comparative Analysis of Novel Italian and Global Genomes"

This is the repository containing the scripts and data to reproduce the analyses of our paper titled "Genomic Epidemiology and Phylogenomics of _Magnusiomyces clavatus_: A Comparative Analysis of Novel Italian and Global Genomes"

![graphical_ab](Graphical_abstract.png)

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone https://github.com/BCGL-Unime/Mangusiomyces_clavatus_pangenome
```

### 2. Set Up the Conda Environment

```bash
conda env create -f Mclav_pangenome.yaml
```
### 3. Download pangenome files from Zenodo
Link
https://doi.org/10.5281/zenodo.19236704

### 4. Run the pipeline
```bash
chmod +x Variant_calling_pipeline.sh
bash Mclav_pipeline.sh -1 R1.fq.gz -2 R2.fq.gz -s SAMPLE -g graph.gbz -m graph.min -d graph.dist -z graph.zipcodes -r reference.fa -t 24
```
#the reference contig names must follow the PanSN-spec naming 
[sample_name][delim][haplotype_id][delim][contig_or_scaffold_name]
example: HG002#1#ctg1234
In the case of VRMC001 reference: VRMC001#0#CM117174.1 , VRMC001#0#CM117175.1, VRMC001#0#CM117176.1,  VRMC001#0#CM117177.1
