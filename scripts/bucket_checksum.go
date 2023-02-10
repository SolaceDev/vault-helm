package main

import (
	"bytes"
	"context"
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
)

// listFiles lists objects within specified bucket.
func main() {
	os.Setenv("GOOGLE_APPLICATION_CREDENTIALS",
		os.Getenv("HOME")+"/.config/gcloud/application_default_credentials.json")
	// Sets the name for the new bucket.
	//os.Setenv("bucketName1", "maas-vault-dev-vault-luay-data")
	//os.Setenv("bucketName2", "vault-backup-test-no-vault-connect")
	bucketName1 := os.Getenv("bucketName1")
	bucketName2 := os.Getenv("bucketName2")
	listFile(bucketName1, "bucket1.txt")
	listFile(bucketName2, "bucket2.txt")
	f1, err1 := ioutil.ReadFile("bucket1.txt")

	if err1 != nil {
		log.Fatal(err1)
	}

	f2, err2 := ioutil.ReadFile("bucket2.txt")

	if err2 != nil {
		log.Fatal(err2)
	}
	fmt.Println("If two buckets checksum is the same:", bytes.Equal(f1, f2))
	os.Remove("bucket1.txt")
	os.Remove("bucket2.txt")

}

func listFile(bucketName string, filename string) error {
	ctx := context.Background()
	file, err := os.Create(filename)

	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}
	defer client.Close()
	// Creates a Bucket instance.
	bucket := client.Bucket(bucketName)
	var num int

	it := bucket.Objects(ctx, nil)
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			panic(err)
		}
		defer file.Close()
		num++
		fmt.Fprint(file, attrs.MD5)
		//fmt.Println(attrs.Name+ "\n")
	}
	fmt.Println("Bucket "+bucketName+" has ", num, " files. ")

	return nil

}
