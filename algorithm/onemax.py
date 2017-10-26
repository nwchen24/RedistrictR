# External packages
import random
import ConfigParser
from deap import base
from deap import creator
from deap import tools

# Local modules
import operators

# Create a fitness score. The lone positive 1.0 indicates that it is a single objective that should be maximized
# Probably assigning greater absolute value lets us care more about a given objective? Double check this.
creator.create("FitnessMax", base.Fitness, weights=(1.0,))

# Create an individual, from which populations will be made
# It's of the standard list type, and uses the above Fitness measure
creator.create("Individual", list, fitness=creator.FitnessMax)

# The toolbox contains all the operations to be used in the algorithm
toolbox = base.Toolbox()

# Attribute generator
toolbox.register("attr_bool", random.randint, 0, 1)

# Structure initializers:
# these are creating aliases to already existing functions (initRepeat), and freezing attributes

# How to create a new individual
toolbox.register("individual", tools.initRepeat, creator.Individual, toolbox.attr_bool, 100)

# How to create a new population
# Note that we don't set a number of repetitions, since we don't want to fix it yet.
toolbox.register("population", tools.initRepeat, list, toolbox.individual)

# Registering the genetic operators
# Evaluate is the only operator you always define yourself
toolbox.register("evaluate", operators.evalOneMax)

# Two Point Crossover
# Make two random cuts in both individuals, and swap the areas between them
toolbox.register("mate", tools.cxTwoPoint)

# Flip Bit Mutation
# Set a probability that any given bit will flip
# Probabilities are independent... doesn't matter how many other bits already flipped in this individual
toolbox.register("mutate", tools.mutFlipBit, indpb=0.05)

# Tournament selection
# Randomly select groups of three from the population
# Probabilistically select the winner
# (best fitness score has the highest chance to win, and so on)
# Higher tournsize reduces the chance for very weak individuals to win any given tournament
toolbox.register("select", tools.selTournament, tournsize=3)

# The main function to run the algorithm
def main():
    # Import settings
    config = ConfigParser.ConfigParser()
    config.read("settings.cfg")


    # Instantiate the initial population
    # Here's where we set the population size that we skipped above
    pop = toolbox.population(n=config.get("onemax", "popsize"))

    # Set the operator probabilities
    CXPB, MUTPB = config.get("onemax", "cxpb"), config.get("onemax", "mutpb")

    # Set the initial fitness scores for the entire starting population
    fitnesses = list(map(toolbox.evaluate, pop))
    for ind, fit in zip(pop, fitnesses):
        ind.fitness.values = fit

    # Here's where the actual algorithm starts
    fits = [ind.fitness.values[0] for ind in pop]

    # Keep track of how many generations have passed
    g = 0

    # Get loopin'!
    # If score ever hits 100 we know we're perfect (no equivalent for this in our case)
    # If we make it 1000 generations, give up
    while max(fits) < 100 and g < 1000:
        # Start a new generation
        g = g + 1
        print("-- Generation %i --" % g)

        # Use the selection process to create a new, identical batch on which to perform operations
        # (We don't want to operate in-place on the originals, in case we want to keep some)
        offspring = toolbox.select(pop, len(pop))
        offspring = list(map(toolbox.clone, offspring))

        # For all possible pairs of offspring...
        for child1, child2 in zip(offspring[::2], offspring[1::2]):
            # By some crossover probability, decide whether to mate these two
            if random.random() < CXPB:
                # The mate process changes both parents in place to create two new children
                toolbox.mate(child1, child2)
                # Since the content of both has changed, clear out their fitness values
                del child1.fitness.values
                del child2.fitness.values

        # For all individuals in the offspring
        for mutant in offspring:
            # By some mutation probability, decide whether to mutate
            if random.random() < MUTPB:
                # Use the established mutate function
                toolbox.mutate(mutant)
                # Because the individual has changed, invalidate the fitness value
                del mutant.fitness.values

        # Re-evaluate the fitness scores of anything that doesn't have a fitness score currently
        # (anything that hasn't changed gets to keep its own score.
        # First form the list of individuals without valid scores
        invalid_ind = [ind for ind in offspring if not ind.fitness.valid]

        # Generate and apply scores for all these individuals
        fitnesses = map(toolbox.evaluate, invalid_ind)
        for ind, fit in zip(invalid_ind, fitnesses):
            ind.fitness.values = fit

        # Replace the entire population with the set of offspring
        pop[:] = offspring

        # Check performance stats
        fits = [ind.fitness.values[0] for ind in pop]
        length = len(pop)
        mean = sum(fits) / length
        sum2 = sum(x*x for x in fits)
        std = abs(sum2 / length - mean**2)**0.5

        print("  Min %s" % min(fits))
        print("  Max %s" % max(fits))
        print("  Avg %s" % mean)
        print("  Std %s" % std)

if __name__ == "__main__":
    main()