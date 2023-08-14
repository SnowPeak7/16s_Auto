import argparse
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages

def read_and_plot(file_path, output_pdf):
    # Read the data from the CSV file
    data = pd.read_csv(file_path)

    #Format output title
    plot_title = file_path
    plot_title = (file_path.split('/'))[len(file_path.split('/'))-1]
    plot_title = plot_title.replace('.csv', '')

    # Extracting the maximum depth from the column names
    max_depth = max([int(col.split('-')[1].split('_')[0]) for col in data.columns if col.startswith('depth-')])

    # Extract columns with sample-id and those starting with "depth-"
    selected_columns = data[['sample-id'] + [col for col in data.columns if col.startswith('depth-') and int(col.split('_')[0].split('-')[1]) <= max_depth]]

    # Melt the data and split the depth and iteration
    melted_data = selected_columns.melt(id_vars=['sample-id'], var_name="depth_iter", value_name="value")
    melted_data[['depth', 'iteration']] = melted_data['depth_iter'].str.split('_', expand=True)
    melted_data['depth'] = melted_data['depth'].str.extract('(\d+)').astype(int)

    # Compute means for each depth and sample
    means = melted_data.groupby(['depth', 'sample-id'])['value'].mean().reset_index()

    # Plotting lines connecting the mean values for each sample
    plt.figure(figsize=[15, 8])
    sns.lineplot(x='depth', y='value', hue='sample-id', data=means, marker='o')
    plt.title('Diversity Across Depths for Each Sample (' + plot_title + ')')
    plt.xlabel('Depth')
    plt.ylabel(plot_title) # Using file name without .csv as y-label
    plt.xticks(rotation=90)
    plt.legend(title='Sample ID', bbox_to_anchor=(1.0, 1), loc='upper left')

    # Saving the plot to the PDF
    output_pdf.savefig()
    plt.close()

# Argument parser to handle command-line arguments
parser = argparse.ArgumentParser(description='Plot diversity across depths for given files.')
parser.add_argument('-i', '--input', nargs='+', required=True, help='Input CSV files.')
parser.add_argument('-o', '--output', required=True, help='Output PDF file.')

args = parser.parse_args()

# Creating a PDF to save all the plots
with PdfPages(args.output) as pdf:
    for file_name in args.input:
        read_and_plot(file_name, pdf)
