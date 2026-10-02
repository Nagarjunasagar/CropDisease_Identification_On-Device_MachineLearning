# Data augmentations with python and keras
from json import load
from keras.preprocessing.image import ImageDataGenerator, array_to_img, img_to_array, load_img
from keras.models import Sequential
from keras.layers import Conv2D, MaxPooling2D
from keras.layers import Activation, Dropout, Flatten, Dense
from keras import backend as K
import numpy as np
import matplotlib.pyplot as plt

datagen = ImageDataGenerator( 
    rotation_range=40,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    fill_mode='nearest')

img = load_img('C:\\Users\\NAGARJUNA\\flutter_projects\\croheal\\assets\\images\\tomato_healthy.JPG') # Image to be augmented
x = img_to_array(img) # Convert image to array
x = x.reshape((1,) + x.shape) # Reshape array to 4D array

i = 0 # Counter
for batch in datagen.flow(x, batch_size=1, save_to_dir='C:\\Users\\NAGARJUNA\\data_sets\\tomato_crop_disease_dataset\\Augmented', save_prefix='Tom_healthy', save_format='jpeg'): # Generate augmented images
    i += 1 
    if i > 20:
        break # Break after 20 images have been generated


