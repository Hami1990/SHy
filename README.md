# SHyPar: A Spectral Coarsening Approach to Hypergraph Partitioning

**Authors:** Hamed Sajadinia, Ali Aghdaei, Zhuo Feng  
**Full Paper:** [arXiv:2410.10875](https://arxiv.org/abs/2410.10875)

---

## Abstract

State-of-the-art hypergraph partitioners utilize a multilevel paradigm to construct progressively coarser hypergraphs across multiple layers, guiding cut refinements at each level of the hierarchy. Traditionally, these partitioners employ heuristic methods for coarsening and do not consider the structural features of hypergraphs.  

In this work, we introduce a multilevel spectral framework, **SHyPar**, for partitioning large-scale hypergraphs by leveraging **hyperedge effective resistances** and **flow-based community detection** techniques. Inspired by recent spectral clustering methods like **HyperEF** and **HyperSF**, SHyPar aims to decompose large hypergraphs into subgraphs with minimal inter-partition hyperedges.  

A key component of SHyPar is a **flow-based local clustering** scheme using a max-flow algorithm to yield clusters with improved conductance. Additionally, SHyPar uses an effective resistance-based rating function to merge strongly coupled nodes.  

Our experiments on real-world VLSI benchmarks show SHyPar achieves **state-of-the-art partition quality** compared to existing hypergraph partitioners.

---

## Requirements

SHyPar consists of two integrated components:

### 1. Modified HyperEF and HyperSF (for spectral coarsening)

- **Julia Version:** 1.5.3  
- **Required Packages:**
  - `SparseArrays`
  - `LinearAlgebra`
  - `MatrixNetworks v1.0.1`
  - `RandomV06 v0.0.2`

These modules compute **effective resistance** and perform **flow-based community detection**.

### 2. Modified KaHyPar (for partitioning)

SHyPar uses customized versions of [KaHyPar](https://github.com/kahypar/kahypar) to partition the coarsened hypergraphs.

**KaHyPar Requirements:**

- 64-bit OS (Linux/macOS/WSL)
- CMake (build system)
- C++14-compliant compiler (e.g., `g++ >= 9`, `clang >= 11`)
- Boost header files (or use: `-DKAHYPAR_USE_MINIMAL_BOOST=ON` to build locally)

> Please refer to the documentation of [HyperEF](https://github.com/Feng-Research/HyperEF), [HyperSF](https://github.com/Feng-Research/HyperSF), and [KaHyPar](https://github.com/kahypar/kahypar) for further installation details.

---

## Installation

First, clone the repository:

```bash
git clone https://github.com/Feng-Research/SHyPar.git
cd SHyPar
```

Then, install and build components with:

```bash
chmod +x Install_SHyPar.sh
./Install_SHyPar.sh
```

This script:
- Installs necessary Julia packages
- Builds modified versions of KaHyPar

---

## Running SHyPar

To run SHyPar on your own hypergraph:

1. Place your `.hgr` (hMetis format) hypergraph file in the `data/` directory.
2. Make the run script executable:

```bash
chmod +x Run_SHyPar.sh
```

3. Run SHyPar with the following command:

```bash
./Run_SHyPar.sh <hypergraph_filename> <#coarsening_levels> <#partitions> <imbalance>
```

### Example:

```bash
./Run_SHyPar.sh dataset.hgr 4 8 0.04
```

This runs SHyPar on `dataset.hgr` with 4 levels of coarsening, dividing into 8 partitions, allowing up to 4% imbalance.

---

## Project Structure

```
SHyPar/
├── HyperEF/             # Julia source code for coarsening & clustering 
├── KaHyPar/             # Modified KaHyPar variants 
├── HyperSF/             # Julia source code for coarsening & clustering 
├── data/                # Datasets
├── results/             # Output partitions 
├── Run_SHyPar.sh        # Master run script
├── Install_SHyPar.sh    # Installation script 
└── README.md
```

---

## Citation

If you use this code in your research, please cite the following paper:

```bibtex
@article{sajadinia2025shypar,
  title={SHyPar: A Spectral Coarsening Approach to Hypergraph Partitioning},
  author={Hamed Sajadinia and Ali Aghdaei and Zhuo Feng},
  journal={arXiv preprint arXiv:2410.10875},
  year={2025},
  url={https://arxiv.org/abs/2410.10875}
}
```

---

## References

### Spectral Coarsening Techniques:

Aghdaei, Ali, Zhiqiang Zhao, and Zhuo Feng. "HyperSF: Spectral hypergraph coarsening via flow-based local clustering." 2021 IEEE/ACM International Conference On Computer Aided Design (ICCAD). IEEE, 2021.

Aghdaei, Ali, and Zhuo Feng. "HyperEF: Spectral hypergraph coarsening by effective-resistance clustering." Proceedings of the 41st IEEE/ACM International Conference on Computer-Aided Design. 2022.

### KaHyPar Framework and Variants:

Schlag, Sebastian, et al. "High-quality hypergraph partitioning." ACM Journal of Experimental Algorithmics 27 (2023): 1-39.

Schlag, Sebastian, et al. "K-way hypergraph partitioning via n-level recursive bisection." 2016 Proceedings of the Eighteenth Workshop on Algorithm Engineering and Experiments (ALENEX). Society for Industrial and Applied Mathematics, 2016.

Akhremtsev, Yaroslav, et al. "Engineering a direct k-way hypergraph partitioning algorithm." 2017 Proceedings of the Ninteenth Workshop on Algorithm Engineering and Experiments (ALENEX). Society for Industrial and Applied Mathematics, 2017.

Heuer, Tobias, and Sebastian Schlag. "Improving coarsening schemes for hypergraph partitioning by exploiting community structure." 16th international symposium on experimental algorithms (SEA 2017). Schloss Dagstuhl–Leibniz-Zentrum für Informatik, 2017.

Heuer, Tobias, Peter Sanders, and Sebastian Schlag. "Network flow-based refinement for multilevel hypergraph partitioning." Journal of Experimental Algorithmics (JEA) 24 (2019): 1-36.

Andre, Robin, Sebastian Schlag, and Christian Schulz. "Memetic multilevel hypergraph partitioning." Proceedings of the Genetic and Evolutionary Computation Conference. 2018.

Gottesbüren, Lars, et al. "Advanced flow-based multilevel hypergraph partitioning." arXiv preprint arXiv:2003.12110 (2020).