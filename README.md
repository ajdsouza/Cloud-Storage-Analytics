Count the storage used in the cloud and the allocation and utilization of that storage up to the application.

Be able to track the applications that are using a disk spindle.


-  Instrument metric for all layers of storage in the cloud
-  Uniquely identify each storage element
-  Map its allocation and usage
-  Build the Storage tree 
-  Aggregeate over applications, Storage Devices


Compute storage summary from a storage layout tree
--------------------------------------------------

1. Identify the input entities for each layer
   - Entities from another storage_layer which provide storage to this layer
   - Entities from this layer which are not parents

2. Get the Used space in the input entities
   - Sum of all the space used by entities which are the direct parents of the input entity in that storage layer.

3. Get the free space in the input entities
   - ( Size of the input entity -  used space in the entity )

2. Identify the output entities for each layer
   - Entities from this storage_layer which are used in another layer
   - Entities from this layer which have no parents entities.

3. Raw Size = Sum of the size of input entities

4. Size = Sum of the size of output devices + Free space in input devices

5. Free = Free space in input devices +  Free space in  output entities


Template
	Storge Layer	Entity		Top/Bottom/Intermediate

Storage Tree


	
