import configparser
import utils
import district

section = "functiontest"
config = configparser.ConfigParser()
config.read("settings.cfg")

district.data, district.adjacency, district.edges = utils.loadData(config.get(section, "dataset"))
district.max_mutation_units = config.getint(section, "max_mutation_units")

k = config.getint(section, "num_districts")

def main():
    individual = district.initial(k)
    print(individual)

    for i in range(k*2):
        src = (i % k) + 1
        dst = ((i+1) % k) + 1

        individual = district.shift(individual, src, dst)
        print(individual)


if __name__ == "__main__":
    main()