#!/usr/bin/env python3
import sys
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import coremltools as ct

def convert_phi2_to_coreml(output_path):
    print("Loading Phi-2 model...")
    model_id = "microsoft/phi-2"
    model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.float16)
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    
    print("Converting to CoreML format...")
    # Prepare example input
    example_text = "You are a video editing assistant. Help me edit this video."
    inputs = tokenizer(example_text, return_tensors="pt")
    
    # Trace the model
    traced_model = torch.jit.trace(model, (inputs["input_ids"],))
    
    # Convert to CoreML
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(
                name="input_ids",
                shape=ct.Shape(shape=(1, -1)),  # Dynamic sequence length
                dtype=ct.int32
            )
        ],
        outputs=[
            ct.TensorType(
                name="output_logits",
                dtype=ct.float16
            )
        ],
        minimum_deployment_target=ct.target.macOS13,
        compute_precision=ct.precision.FLOAT16,
        compute_units=ct.ComputeUnit.ALL
    )
    
    # Add model metadata
    mlmodel.author = "Microsoft (original) / CoolVideoEditor (converted)"
    mlmodel.license = "MIT"
    mlmodel.short_description = "Phi-2 language model optimized for video editing assistance"
    mlmodel.version = "1.0.0"
    
    # Add the tokenizer as model metadata
    mlmodel.user_defined_metadata["tokenizer_vocab"] = str(tokenizer.get_vocab())
    mlmodel.user_defined_metadata["tokenizer_type"] = "microsoft/phi-2"
    
    print(f"Saving model to {output_path}...")
    mlmodel.save(output_path)
    print("Conversion complete!")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: convert_model.py <output_path>")
        sys.exit(1)
    
    convert_phi2_to_coreml(sys.argv[1]) 