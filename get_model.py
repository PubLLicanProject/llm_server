from huggingface_hub import snapshot_download
import os
import sys
import subprocess

quant_options = ["Q8_0", "Q6_K", "Q5_K_M", "Q4_K_M"]

def main(model_id):
	root = "./models/"
	download_root = root+"downloads/"
	if not os.path.exists(root):
	    os.makedirs(root)
	if not os.path.exists(download_root):
	    os.makedirs(download_root)

	model_root = model_id.split("/")[0]
	model_name = model_id.split("/")[1]





	download_model_root = download_root+model_root
	if not os.path.exists(download_model_root):
	    os.makedirs(download_model_root)

	download_path = download_root + model_id

	snapshot_download(repo_id=model_id, local_dir=download_path,
	                  revision="main")


	output_root = root+model_root
	if not os.path.exists(output_root):
	    os.makedirs(output_root)

	gguf_path = output_root+"/"+model_name+".gguf"

	#write out the original (usually 16 bit) model to a gguf file for quantising
	exec_list = ["python","llama.cpp/convert_hf_to_gguf.py",download_path, "--outfile",gguf_path]
	subprocess.run(exec_list)


	#use the new  gguf to quantise
	for quant_name in quant_options:

		output_path = output_root+"/"+model_name+"_"+quant_name+".gguf"
		exec_list = ["llama.cpp/llama-quantize",gguf_path,output_path,quant_name]
		subprocess.run(exec_list)

if __name__ == "__main__":
	if len(sys.argv) < 2:
		print("usage: python get_model.py model_id (e.g. google-t5/t5-small)")
		print("Set to quantise for: "+",".join(quant_options))
	else:
		model_id = sys.argv[1]
		main(model_id)
