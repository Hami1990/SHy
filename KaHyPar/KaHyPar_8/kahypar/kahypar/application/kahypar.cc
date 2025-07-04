/*******************************************************************************
 * This file is part of KaHyPar.
 *
 * Copyright (C) 2014-2016 Sebastian Schlag <sebastian.schlag@kit.edu>
 *
 * KaHyPar is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * KaHyPar is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with KaHyPar.  If not, see <http://www.gnu.org/licenses/>.
 *
 ******************************************************************************/

#include "kahypar/application/command_line_options.h"
#include "kahypar/definitions.h"
#include "kahypar/io/hypergraph_io.h"
#include "kahypar/partitioner_facade.h"
#include "kahypar/datastructure/hypergraph.h"

#include "kahypar/utils/signal_handling.h"

#include <csignal>
#include <functional>
#include <iostream>
#include <fstream>
#include <vector>
// std::vector<int> numberss;    // Vector to store integers
//  not pretty. but signal handling needs it.
kahypar::Context *kahypar::SerializeOnSignal::context_p = nullptr;
kahypar::Hypergraph *kahypar::SerializeOnSignal::hypergraph_p = nullptr;

int main(int argc, char *argv[])
{
  kahypar::Context context;

  //********************************************
  std::ifstream file(argv[1]); // Open the file
                               // Vector to store integers

  float temp;
  if (!file)
  {
    std::cerr << "Unable to open ER file \n";
    return 1; // Return an error code
  }
  while (file >> temp)
  {                           // Read integers from file
    numberss.push_back(temp); // Add integers to the vector
  }

  file.close(); // Close the file
  //********************************************
  std::ifstream file1(argv[2]); // Open the file
                               // Vector to store integers

  float temp1;
  if (!file1)
  {
    std::cerr << "Unable to open idx file \n";
    return 1; // Return an error code
  }
  while (file1 >> temp1)
  {                           // Read integers from file
    community_numbers.push_back(temp1); // Add integers to the vector
  }

  file1.close(); // Close the file


  for (int i = 3; i < argc; ++i)
  {
    argv[i - 2] = argv[i];
  }
  argc--;
  argc--;
  
  //********************************************
  kahypar::processCommandLineInput(context, argc, argv);

  kahypar::Hypergraph hypergraph(
      kahypar::io::createHypergraphFromFile(context.partition.graph_filename,
                                            context.partition.k,
                                            VALIDATE_INPUT,
                                            PROMOTE_WARNINGS_TO_ERRORS));

  kahypar::SerializeOnSignal::initialize(hypergraph, context);

  kahypar::PartitionerFacade().partition(hypergraph, context);

  return 0;
}
