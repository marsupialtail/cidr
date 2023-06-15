import pyarrow.parquet as pq
from pyarrow.fs import S3FileSystem
import pyarrow.compute as compute
import time
import concurrent.futures
import pyarrow as pa
import polars

class InputEC2ParquetDataset:

    # filter pushdown could be profitable in the future, especially when you can skip entire Parquet files
    # but when you can't it seems like you still read in the entire thing anyways
    # might as well do the filtering at the Pandas step. Also you need to map filters to the DNF form of tuples, which could be
    # an interesting project in itself. Time for an intern?

    def __init__(self, files = None, columns=None, filters=None) -> None:

        self.files = files

        self.columns = columns
        self.filters = filters

        self.length = 0
        self.workers = 4

        self.s3 = S3FileSystem()
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=self.workers)
        self.iterator = None
        self.count = 0


    def execute(self, mapper_id, files_to_do=None):            

        def download(file):
            if self.columns is not None:
                return pq.read_table( file, columns=self.columns, filters=self.filters, use_threads= True, filesystem = self.s3)
            else:
                return pq.read_table( file, filters=self.filters, use_threads= True, filesystem = self.s3)

        if files_to_do is None:
            raise Exception("dynamic lineage for inputs not supported anymore")

        if len(files_to_do) == 0:
            return None, None
        
        # this will return things out of order, but that's ok!

        future_to_url = {self.executor.submit(download, file): file for file in files_to_do}
        dfs = []
        for future in concurrent.futures.as_completed(future_to_url):
            dfs.append(future.result())
        
        return None, pa.concat_tables(dfs)


def read():
    reader = InputEC2ParquetDataset(columns = ['l_shipdate','l_commitdate','l_shipmode','l_receiptdate','l_orderkey'], filters=[('l_shipmode', 'in', ['SHIP','MAIL']),('l_receiptdate','<',compute.strptime("1995-01-01",format="%Y-%m-%d",unit="s")), ('l_receiptdate','>=',compute.strptime("1994-01-01",format="%Y-%m-%d",unit="s"))])
    reader.execute(0, ["yugan/lineitem.parquet"] * 8)
    times = []
    for i in range(5):
        start = time.time()
        reader.execute(0, ["yugan/lineitem.parquet"] * 8)
        times.append(time.time() - start)
    print(times)
    
def read1():
    reader = InputEC2ParquetDataset(columns = ['l_shipdate','l_commitdate','l_shipmode','l_receiptdate','l_orderkey'])
    reader.execute(0, ["yugan/lineitem.parquet"] * 8)
    times = []
    for i in range(5):
        start = time.time()
        reader.execute(0, ["yugan/lineitem.parquet"] * 8)
        times.append(time.time() - start)
    print(times)

def join():
    lineitem = polars.from_arrow(pq.read_table("yugan/lineitem.parquet", columns = ['l_shipdate','l_commitdate','l_shipmode','l_receiptdate','l_orderkey'],filesystem=S3FileSystem()))
    orders = polars.from_arrow(pq.read_table("yugan/orders.parquet", columns = ['o_orderkey','o_orderpriority'] , filesystem=S3FileSystem()))
    times = []
    for i in range(5):
        start = time.time()
        lineitem.join(orders, left_on="l_orderkey", right_on="o_orderkey")
        times.append(time.time() - start)
    print(times)

read()
read1()
join()
